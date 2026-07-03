require "./spec_helper"
require "kemal"

include Kemal

def rate_limited_harpy_response(
  client_ip : String,
  rate_limiter : Harpy::RateLimiter = Harpy::RateLimiter.new(max_tokens: 1, refill_seconds: 60),
)
  Kemal.config.clear
  Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
  Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Kemal::Route).new
  Kemal::RouteHandler::INSTANCE.cached_routes =
    Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
  Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(Kemal::WebSocket).new

  storage_path = File.tempname
  Harpy::Storage.save(Harpy::SpecHelpers.build_chain(1), storage_path)
  Harpy::Server.reset!(storage_path)
  Harpy::Server.configure_kemal!(rate_limiter)
  Harpy::Server.register_routes!

  request = HTTP::Request.new("POST", "/mine")
  request.headers["Content-Type"] = "application/json"
  request.headers["X-Forwarded-For"] = client_ip
  _, verify_key = Harpy::SpecHelpers.generate_keypair
  pubkey = Harpy::Crypto.pubkey_hex(verify_key)
  body = %({"miner_pubkey":"#{pubkey}"})
  request.body = IO::Memory.new(body.to_slice)
  request.headers["Content-Length"] = body.bytesize.to_s

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
ensure
  File.delete?(storage_path) if storage_path && File.exists?(storage_path)
end

describe Harpy::RateLimiter do
  it "allows burst traffic up to the configured maximum" do
    limiter = Harpy::RateLimiter.new(max_tokens: 2, refill_seconds: 60)

    limiter.allow?("127.0.0.1").should be_true
    limiter.allow?("127.0.0.1").should be_true
    limiter.allow?("127.0.0.1").should be_false
  end

  it "tracks limits independently per client key" do
    limiter = Harpy::RateLimiter.new(max_tokens: 1, refill_seconds: 60)

    limiter.allow?("client-a").should be_true
    limiter.allow?("client-a").should be_false
    limiter.allow?("client-b").should be_true
  end
end

describe "POST /mine rate limiting" do
  it "returns 429 when the per-IP token bucket is exhausted" do
    limiter = Harpy::RateLimiter.new(max_tokens: 1, refill_seconds: 60)

    first = rate_limited_harpy_response("203.0.113.10", rate_limiter: limiter)
    first.status_code.should eq(200)

    second = rate_limited_harpy_response("203.0.113.10", rate_limiter: limiter)
    second.status_code.should eq(429)
    second.body.should eq(%({"error":"rate limit exceeded"}))
  end

  it "ignores a spoofed X-Forwarded-For by default so it cannot escape the limit" do
    limiter = Harpy::RateLimiter.new(max_tokens: 1, refill_seconds: 60)

    Harpy::SpecHelpers.with_env("HARPY_TRUST_PROXY", nil) do
      first = rate_limited_harpy_response("1.1.1.1", rate_limiter: limiter)
      first.status_code.should eq(200)

      # A different forged X-Forwarded-For must NOT be treated as a new client
      # when the proxy is untrusted — both collapse to the real peer identity.
      second = rate_limited_harpy_response("2.2.2.2", rate_limiter: limiter)
      second.status_code.should eq(429)
    end
  end

  it "honors X-Forwarded-For only when HARPY_TRUST_PROXY is set" do
    limiter = Harpy::RateLimiter.new(max_tokens: 1, refill_seconds: 60)

    Harpy::SpecHelpers.with_env("HARPY_TRUST_PROXY", "1") do
      first = rate_limited_harpy_response("1.1.1.1", rate_limiter: limiter)
      first.status_code.should eq(200)

      second = rate_limited_harpy_response("2.2.2.2", rate_limiter: limiter)
      second.status_code.should eq(200)
    end
  end

  it "does not rate limit GET /" do
    Kemal.config.clear
    Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
    Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Kemal::Route).new
    Kemal::RouteHandler::INSTANCE.cached_routes =
      Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
    Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(Kemal::WebSocket).new

    storage_path = File.tempname
    Harpy::Storage.save(Harpy::SpecHelpers.build_chain(1), storage_path)
    Harpy::Server.reset!(storage_path)
    Harpy::Server.configure_kemal!(Harpy::RateLimiter.new(max_tokens: 0, refill_seconds: 60))
    Harpy::Server.register_routes!

    request = HTTP::Request.new("GET", "/")
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
    HTTP::Client::Response.from_io(io, decompress: false).status_code.should eq(200)
  ensure
    File.delete?(storage_path) if storage_path && File.exists?(storage_path)
  end
end
