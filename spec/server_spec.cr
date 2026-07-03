require "./spec_helper"
require "kemal"

include Kemal

def harpy_call_request(request : HTTP::Request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  Kemal.config.setup
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each do |handler|
    current_handler.not_nil!.next = handler
    current_handler = handler
  end
  main_handler.not_nil!.call(context)
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def harpy_test_response(
  method : String,
  path : String,
  body : String? = nil,
  api_key : String? = nil,
  headers : Hash(String, String) = {} of String => String,
  rate_limiter : Harpy::RateLimiter = Harpy::RateLimiter.new(max_tokens: 100, refill_seconds: 60),
)
  Kemal.config.clear
  Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
  Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Kemal::Route).new
  Kemal::RouteHandler::INSTANCE.cached_routes =
    Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
  Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(Kemal::WebSocket).new

  storage_path = File.tempname
  Harpy::Storage.save(Harpy::SpecHelpers.build_chain(1), storage_path)
  Harpy::Server.reset!(storage_path, api_key)
  Harpy::Server.configure_kemal!(rate_limiter)
  Harpy::Server.register_routes!

  request = HTTP::Request.new(method, path)
  request.headers["Content-Type"] = "application/json"
  headers.each { |name, value| request.headers[name] = value }

  if body
    request.body = IO::Memory.new(body.to_slice)
    request.headers["Content-Length"] = body.bytesize.to_s
  end

  harpy_call_request(request)
ensure
  File.delete?(storage_path) if storage_path && File.exists?(storage_path)
end

describe "GET /health" do
  it "reports chain validity and a last-saved timestamp" do
    response = harpy_test_response("GET", "/health")

    response.status_code.should eq(200)
    body = JSON.parse(response.body)
    body["valid"].as_bool.should be_true
    body["last_saved_at"].as_s.should_not be_empty
  end
end

describe "GET /mempool" do
  it "returns an empty mempool on a fresh chain" do
    response = harpy_test_response("GET", "/mempool")

    response.status_code.should eq(200)
    JSON.parse(response.body)["transactions"].as_a.should be_empty
  end
end

describe "POST /mine" do
  it "mines and appends a coinbase-only block" do
    _, verify_key = Harpy::SpecHelpers.generate_keypair
    pubkey = Harpy::Crypto.pubkey_hex(verify_key)
    response = harpy_test_response("POST", "/mine", %({"miner_pubkey":"#{pubkey}"}))

    response.status_code.should eq(200)
    JSON.parse(response.body)["index"].as_i.should eq(1)
  end

  it "returns 401 when the API key is required but missing" do
    _, verify_key = Harpy::SpecHelpers.generate_keypair
    pubkey = Harpy::Crypto.pubkey_hex(verify_key)
    response = harpy_test_response("POST", "/mine", %({"miner_pubkey":"#{pubkey}"}), api_key: "secret")

    response.status_code.should eq(401)
    response.body.should eq(%({"error":"unauthorized"}))
  end
end

describe "POST /mine request limits" do
  it "rejects HTTP bodies larger than the configured limit with 413" do
    oversized = %({"miner_pubkey":"#{"x" * (Harpy::Config.max_request_body_bytes + 1)}"})
    response = harpy_test_response("POST", "/mine", oversized)

    response.status_code.should eq(413)
    response.body.should eq(%({"error":"request body too large"}))
  end
end
