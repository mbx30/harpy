require "./spec_helper"
require "./server_spec"

# Async mining job queue (MIC-44): unit tests for the queue plus a
# multi-request route session (submit → work → poll), which the one-shot
# harpy_test_response harness cannot express because it resets state per call.

private def with_harpy_session(&)
  Kemal.config.clear
  Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
  Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Kemal::Route).new
  Kemal::RouteHandler::INSTANCE.cached_routes =
    Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
  Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(Kemal::WebSocket).new

  storage_path = File.tempname
  Harpy::Storage.save(Harpy::SpecHelpers.build_chain(1), storage_path)
  Harpy::Server.reset!(storage_path, nil)
  Harpy::Server.configure_kemal!(Harpy::RateLimiter.new(max_tokens: 100, refill_seconds: 60))
  Harpy::Server.register_routes!

  request = ->(method : String, path : String, body : String?) do
    http_request = HTTP::Request.new(method, path)
    http_request.headers["Content-Type"] = "application/json"
    if body
      http_request.body = IO::Memory.new(body.to_slice)
      http_request.headers["Content-Length"] = body.bytesize.to_s
    end
    harpy_call_request(http_request)
  end

  yield request
ensure
  File.delete?(storage_path) if storage_path && File.exists?(storage_path)
end

private def spec_miner_pubkey : String
  _, verify_key = Harpy::SpecHelpers.generate_keypair
  Harpy::Crypto.pubkey_hex(verify_key)
end

describe Harpy::MineJobs do
  it "enqueues up to MAX_QUEUE jobs then reports full" do
    Harpy::MineJobs.reset!
    jobs = (1..Harpy::MineJobs::MAX_QUEUE).map do |i|
      job = Harpy::MineJobs.enqueue("pubkey-#{i}")
      job.should_not be_nil
      job.not_nil!
    end
    Harpy::MineJobs.enqueue("overflow").should be_nil
    jobs.each { |job| Harpy::MineJobs.find(job.id).should eq(job) }
  end

  it "runs a job through the worker and records the result" do
    Harpy::MineJobs.reset!
    job = Harpy::MineJobs.enqueue("worker-pubkey").not_nil!

    block = Harpy::SpecHelpers.mined_genesis
    Harpy::MineJobs.work_one { |_pubkey| block }.should be_true

    job.state.should eq(Harpy::MineJobs::State::Done)
    job.block.should eq(block)
    job.error.should be_nil
  end

  it "marks a job failed when the miner raises" do
    Harpy::MineJobs.reset!
    job = Harpy::MineJobs.enqueue("failing-pubkey").not_nil!

    Harpy::MineJobs.work_one { |_pubkey| raise Harpy::Server::MiningRejected.new("rejected") }.should be_true

    job.state.should eq(Harpy::MineJobs::State::Failed)
    job.error.should eq("rejected")
    job.block.should be_nil
  end

  it "returns false from work_one once the queue is closed" do
    Harpy::MineJobs.reset!
    # A blocked worker must exit cleanly when reset! closes the queue.
    spawn { Harpy::MineJobs.reset! }
    Harpy::MineJobs.work_one { |_pubkey| Harpy::SpecHelpers.mined_genesis }.should be_false
  end
end

describe "POST /mine async (202 + job id)" do
  it "accepts an async job, mines it via the worker, and serves the poll endpoint" do
    with_harpy_session do |request|
      pubkey = spec_miner_pubkey

      response = request.call("POST", "/mine", %({"miner_pubkey":"#{pubkey}","async":true}))
      response.status_code.should eq(202)
      body = JSON.parse(response.body)
      job_id = body["job_id"].as_s
      body["poll"].as_s.should eq("/mine-jobs/#{job_id}")

      pending_poll = request.call("GET", "/mine-jobs/#{job_id}", nil)
      pending_poll.status_code.should eq(200)
      JSON.parse(pending_poll.body)["state"].as_s.downcase.should eq("queued")

      # Drain the queue inline (specs do not run the background worker fiber).
      Harpy::MineJobs.work_one { |miner| Harpy::Server.mine_block!(miner) }.should be_true

      done_poll = request.call("GET", "/mine-jobs/#{job_id}", nil)
      done_poll.status_code.should eq(200)
      done = JSON.parse(done_poll.body)
      done["state"].as_s.downcase.should eq("done")
      done["block"]["index"].as_i.should eq(1)

      # The mined block landed on the chain exactly as a sync mine would.
      chain_response = request.call("GET", "/validate", nil)
      JSON.parse(chain_response.body)["height"].as_i.should eq(2) # genesis + mined block
    end
  end

  it "404s for an unknown job id" do
    with_harpy_session do |request|
      response = request.call("GET", "/mine-jobs/doesnotexist", nil)
      response.status_code.should eq(404)
    end
  end

  it "returns 503 when the queue is full" do
    with_harpy_session do |request|
      pubkey = spec_miner_pubkey
      Harpy::MineJobs::MAX_QUEUE.times do
        request.call("POST", "/mine", %({"miner_pubkey":"#{pubkey}","async":true})).status_code.should eq(202)
      end
      overflow = request.call("POST", "/mine", %({"miner_pubkey":"#{pubkey}","async":true}))
      overflow.status_code.should eq(503)
    end
  end

  it "still mines synchronously when async is absent" do
    with_harpy_session do |request|
      pubkey = spec_miner_pubkey
      response = request.call("POST", "/mine", %({"miner_pubkey":"#{pubkey}"}))
      response.status_code.should eq(200)
      JSON.parse(response.body)["index"].as_i.should eq(1)
    end
  end
end
