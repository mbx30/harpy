module Harpy
  module P2p
    # Local reputation scoring (StarveSpam-style) for mempool and gossip spam control.
    class Reputation
      INITIAL_SCORE                 = 100
      MIN_SCORE                     =   0
      MAX_SCORE                     = 200
      SPAM_PENALTY                  =  10
      INVALID_PENALTY               =  25
      GOOD_BLOCK_BONUS              =   2
      RATE_WINDOW_SEC               =  10
      MAX_INV_HASHES_PER_WINDOW     =  50
      MAX_BLOCK_REQUESTS_PER_WINDOW =  10
      MAX_BLOCK_BYTES_PER_REQUEST   = 2 * 1024 * 1024
      MAX_BLOCK_BYTES_PER_WINDOW    = 8 * 1024 * 1024
      MAX_SYNC_CONTROLS_PER_WINDOW  = 2

      record InvEvent, at : Time, count : Int32
      record BlockResponseEvent, at : Time, bytes : Int32

      def initialize
        @scores = {} of String => Int32
        @inv_events = {} of String => Array(InvEvent)
        @block_response_events = {} of String => Array(BlockResponseEvent)
        @sync_control_events = {} of String => Array(Time)
        @mutex = Mutex.new
      end

      def record_sync_control(peer_id : String, now : Time = Time.utc) : Bool
        @mutex.synchronize do
          window = @sync_control_events[peer_id]? || [] of Time
          window.reject! { |at| (now - at).total_seconds > RATE_WINDOW_SEC }

          if window.size >= MAX_SYNC_CONTROLS_PER_WINDOW
            penalize_unlocked(peer_id, SPAM_PENALTY)
            @sync_control_events[peer_id] = window
            return false
          end

          window << now
          @sync_control_events[peer_id] = window
          true
        end
      end

      def record_block_response(peer_id : String, byte_count : Int32, now : Time = Time.utc) : Bool
        @mutex.synchronize do
          window = @block_response_events[peer_id]? || [] of BlockResponseEvent
          window.reject! { |event| (now - event.at).total_seconds > RATE_WINDOW_SEC }
          total_bytes = window.sum(0, &.bytes)

          if byte_count <= 0 ||
             byte_count > MAX_BLOCK_BYTES_PER_REQUEST ||
             window.size >= MAX_BLOCK_REQUESTS_PER_WINDOW ||
             total_bytes + byte_count > MAX_BLOCK_BYTES_PER_WINDOW
            penalize_unlocked(peer_id, SPAM_PENALTY)
            @block_response_events[peer_id] = window
            return false
          end

          window << BlockResponseEvent.new(now, byte_count)
          @block_response_events[peer_id] = window
          true
        end
      end

      def score(peer_id : String) : Int32
        @mutex.synchronize { score_unlocked(peer_id) }
      end

      def record_inv(peer_id : String, hash_count : Int32, now : Time = Time.utc) : Bool
        @mutex.synchronize do
          window = @inv_events[peer_id]? || [] of InvEvent
          window.reject! { |event| (now - event.at).total_seconds > RATE_WINDOW_SEC }
          total = window.sum(0, &.count)

          if hash_count <= 0 || total + hash_count > MAX_INV_HASHES_PER_WINDOW
            penalize_unlocked(peer_id, SPAM_PENALTY)
            @inv_events[peer_id] = window
            return false
          end

          window << InvEvent.new(now, hash_count)
          @inv_events[peer_id] = window
          true
        end
      end

      def penalize(peer_id : String, amount : Int32 = INVALID_PENALTY) : Nil
        @mutex.synchronize { penalize_unlocked(peer_id, amount) }
      end

      def reward(peer_id : String, amount : Int32 = GOOD_BLOCK_BONUS) : Nil
        @mutex.synchronize do
          @scores[peer_id] = Math.min(MAX_SCORE, score_unlocked(peer_id) + amount)
        end
      end

      def deprioritized?(peer_id : String) : Bool
        @mutex.synchronize do
          return true if score_unlocked(peer_id) < 50

          now = Time.utc
          window = @inv_events[peer_id]? || [] of InvEvent
          window.sum(0) do |event|
            (now - event.at).total_seconds <= RATE_WINDOW_SEC ? event.count : 0
          end >= MAX_INV_HASHES_PER_WINDOW
        end
      end

      private def score_unlocked(peer_id : String) : Int32
        @scores[peer_id]? || INITIAL_SCORE
      end

      private def penalize_unlocked(peer_id : String, amount : Int32) : Nil
        @scores[peer_id] = Math.max(MIN_SCORE, score_unlocked(peer_id) - amount)
      end
    end
  end
end
