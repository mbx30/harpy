require "random/secure"

module Harpy
  # Async mining job queue (MIC-44).
  #
  # `POST /mine` with `"async": true` enqueues a job and returns
  # `202 Accepted` + a job id instead of grinding PoW inside the request.
  # A single worker fiber drains the queue, so an attacker who passes auth
  # and rate limits can still only ever occupy one mining lane — CPU abuse
  # on the write path is bounded by queue depth, not by request volume.
  module MineJobs
    extend self

    MAX_QUEUE    =  8 # queued-but-unstarted jobs; enqueue past this → 503
    MAX_RETAINED = 64 # finished jobs kept for polling before pruning

    enum State
      Queued
      Running
      Done
      Failed
    end

    class Job
      include JSON::Serializable

      getter id : String
      getter miner_pubkey : String
      property state : State
      property block : Block?
      property error : String?

      def initialize(@id : String, @miner_pubkey : String)
        @state = State::Queued
        @block = nil
        @error = nil
      end

      def finished? : Bool
        state.done? || state.failed?
      end
    end

    @@jobs = {} of String => Job
    @@pending = Channel(Job).new(MAX_QUEUE)

    def reset!
      @@pending.close
      @@pending = Channel(Job).new(MAX_QUEUE)
      @@jobs = {} of String => Job
    end

    # Returns the queued job, or nil when the queue is full.
    def enqueue(miner_pubkey : String) : Job?
      prune!
      job = Job.new(Random::Secure.hex(8), miner_pubkey)
      select
      when @@pending.send(job)
        @@jobs[job.id] = job
        job
      else
        nil
      end
    end

    def find(id : String) : Job?
      @@jobs[id]?
    end

    def queued_count : Int32
      @@jobs.count { |_, job| job.state.queued? }
    end

    # Blockingly take one job off the queue and run it through `miner`.
    # Returns false when the queue has been closed (server reset).
    def work_one(&miner : String -> Block) : Bool
      job = @@pending.receive?
      return false unless job
      # A reset! swaps @@jobs while a job is in flight; only publish results
      # for jobs the current registry still knows about.
      return true unless @@jobs[job.id]? == job

      job.state = State::Running
      begin
        job.block = miner.call(job.miner_pubkey)
        job.state = State::Done
      rescue ex
        job.error = ex.message || ex.class.name
        job.state = State::Failed
      end
      true
    end

    # Run until the queue is closed. Intended for a dedicated fiber.
    def run_worker(&miner : String -> Block) : Nil
      loop do
        break unless work_one(&miner)
      end
    end

    # Drop oldest finished jobs beyond the retention cap (insertion order).
    private def prune!
      finished = @@jobs.select { |_, job| job.finished? }
      overflow = finished.size - MAX_RETAINED
      return if overflow <= 0

      finished.each_key.first(overflow).each { |id| @@jobs.delete(id) }
    end
  end
end
