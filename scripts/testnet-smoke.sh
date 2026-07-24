#!/usr/bin/env bash
set -euo pipefail

project="${HARPY_COMPOSE_PROJECT:-harpy-ci-testnet}"
compose=(docker compose -p "$project" -f docker-compose.testnet.yml)
api_key="${HARPY_API_KEY:?HARPY_API_KEY must be set}"
miner_pubkey="${HARPY_GENESIS_PUBKEY:-a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456}"
export HARPY_RATE_LIMIT="${HARPY_RATE_LIMIT:-100}"

cleanup() {
  "${compose[@]}" down -v --remove-orphans
}
trap cleanup EXIT

wait_health() {
  local port="$1"
  for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

mine_host() {
  local port="$1"
  curl -fsS -X POST "http://127.0.0.1:${port}/mine" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"miner_pubkey\":\"${miner_pubkey}\"}" >/dev/null
}

read_validate() {
  local port="$1"
  curl -fsS "http://127.0.0.1:${port}/validate"
}

wait_convergence() {
  local expected_height="$1"
  for _ in $(seq 1 60); do
    local a b c
    a="$(read_validate 3001)"
    b="$(read_validate 3002)"
    c="$(read_validate 3003)"
    if [[ "$(jq -r .height <<<"$a")" == "$expected_height" \
      && "$(jq -r .tip <<<"$a")" == "$(jq -r .tip <<<"$b")" \
      && "$(jq -r .tip <<<"$a")" == "$(jq -r .tip <<<"$c")" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

"${compose[@]}" up -d --build
wait_health 3001
wait_health 3002
wait_health 3003

genesis_a="$(jq -r .tip <<<"$(read_validate 3001)")"
genesis_b="$(jq -r .tip <<<"$(read_validate 3002)")"
genesis_c="$(jq -r .tip <<<"$(read_validate 3003)")"
test "$genesis_a" = "$genesis_b"
test "$genesis_a" = "$genesis_c"

mine_host 3001
wait_convergence 2

# Build two competing branches, then reconnect the longer node3 branch. The
# bounded ancestor-first catch-up supplies every missing block before reorg.
node3_id="$("${compose[@]}" ps -q node3)"
network_name="${project}_default"
docker network disconnect "$network_name" "$node3_id"

mine_host 3001
mine_host 3001

for _ in 1 2 3; do
  docker exec "$node3_id" curl -fsS -X POST http://127.0.0.1:3000/mine \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "{\"miner_pubkey\":\"${miner_pubkey}\"}" >/dev/null
done

docker network connect "$network_name" "$node3_id"
"${compose[@]}" restart node3
wait_health 3003
wait_convergence 5

for port in 3001 3002 3003; do
  test "$(jq -r .valid <<<"$(curl -fsS "http://127.0.0.1:${port}/health")")" = "true"
done
