module Harpy
  module P2p
    # Local reputation scoring (StarveSpam-style) for mempool and gossip spam control.
    class Reputation
      INITIAL_SCORE     = 100
      MIN_SCORE         = 0
      MAX_SCORE         = 200
      SPAM_PENALTY      = 10
      INVALID_PENALTY   = 25
      GOOD_BLOCK_BONUS  = 2
      RATE_WINDOW_SEC   = 10
      MAX_INV_PER_WINDOW = 50

      def initialize
        @scores = {} of String => Int32
        @inv_timestamps = {} of String => Array(Time)
      end

      def score(peer_id : String) : Int32
        @scores[peer_id]? || INITIAL_SCORE
      end

      def record_inv(peer_id : String, now : Time = Time.utc) : Bool
        window = @inv_timestamps[peer_id]? || [] of Time
        window.reject! { |t| (now - t).total_seconds > RATE_WINDOW_SEC }
        window << now
        @inv_timestamps[peer_id] = window

        if window.size > MAX_INV_PER_WINDOW
          penalize(peer_id, SPAM_PENALTY)
          return false
        end

        true
      end

      def penalize(peer_id : String, amount : Int32 = INVALID_PENALTY) : Nil
        current = score(peer_id)
        @scores[peer_id] = Math.max(MIN_SCORE, current - amount)
      end

      def reward(peer_id : String, amount : Int32 = GOOD_BLOCK_BONUS) : Nil
        current = score(peer_id)
        @scores[peer_id] = Math.min(MAX_SCORE, current + amount)
      end

      def deprioritized?(peer_id : String) : Bool
        score(peer_id) < 50
      end
    end
  end
end
