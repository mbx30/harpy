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

describe "POST /new-block request limits" do
  it "rejects HTTP bodies larger than the configured limit with 413" do
    oversized = %({"data":"#{"x" * (Harpy::Config.max_request_body_bytes + 1)}"})
    response = harpy_test_response("POST", "/new-block", oversized)

    response.status_code.should eq(413)
    response.body.should eq(%({"error":"request body too large"}))
  end

  it "rejects block data larger than the configured cap with 400" do
    payload = %({"data":"#{"y" * (Harpy::Config.max_block_data_bytes + 1)}"})
    response = harpy_test_response("POST", "/new-block", payload)

    response.status_code.should eq(400)
    response.body.should eq(%({"error":"block data exceeds maximum size"}))
  end

  it "accepts block data within the configured cap" do
    payload = %({"data":"#{"z" * (Harpy::Config.max_block_data_bytes - 20)}"})
    response = harpy_test_response("POST", "/new-block", payload)

    response.status_code.should eq(200)
    JSON.parse(response.body)["data"].as_s.bytesize.should eq(Harpy::Config.max_block_data_bytes - 20)
  end
end

describe "POST /new-block API key auth" do
  it "returns 401 when the API key is required but missing" do
    response = harpy_test_response("POST", "/new-block", %({"data":"hello"}), api_key: "secret")

    response.status_code.should eq(401)
    response.body.should eq(%({"error":"unauthorized"}))
  end

  it "accepts Authorization Bearer when an API key is configured" do
    response = harpy_test_response(
      "POST",
      "/new-block",
      %({"data":"authenticated"}),
      api_key: "secret",
      headers: {"Authorization" => "Bearer secret"},
    )

    response.status_code.should eq(200)
  end

  it "accepts X-API-Key when an API key is configured" do
    response = harpy_test_response(
      "POST",
      "/new-block",
      %({"data":"authenticated"}),
      api_key: "secret",
      headers: {"X-API-Key" => "secret"},
    )

    response.status_code.should eq(200)
  end
end
