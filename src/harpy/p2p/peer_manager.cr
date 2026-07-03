require "socket"

module Harpy
  module P2p
    enum PeerDirection
      Inbound
      Outbound
      Feeler
    end

    class Peer
      getter id : String
      getter address : String
      getter socket : TCPSocket?
      getter direction : PeerDirection
      property handshake_complete : Bool
      property misbehavior_score : Int32

      def initialize(
        @id : String,
        @address : String,
        @socket : TCPSocket? = nil,
        @direction : PeerDirection = PeerDirection::Inbound,
        @handshake_complete : Bool = false,
        @misbehavior_score : Int32 = 0,
      )
      end

      def mark_misbehavior(amount : Int32 = 1) : Nil
        @misbehavior_score += amount
      end

      def banned?(threshold : Int32) : Bool
        @misbehavior_score >= threshold
      end
    end

    class PeerManager
      MAX_OUTBOUND = 8
      MAX_INBOUND  = 32
      BAN_THRESHOLD = 10

      getter peers : Array(Peer)
      getter banned_until : Hash(String, Time)

      def initialize(
        @eclipse_guard : EclipseGuard = EclipseGuard.new(Config.anchor_peers),
        @reputation : Reputation = Reputation.new,
      )
        @peers = [] of Peer
        @banned_until = {} of String => Time
      end

      def reputation : Reputation
        @reputation
      end

      def eclipse_guard : EclipseGuard
        @eclipse_guard
      end

      def peer_addresses : Array(String)
        @peers.map(&.address)
      end

      def banned?(address : String) : Bool
        if until_time = @banned_until[address]?
          if Time.utc < until_time
            return true
          end
          @banned_until.delete(address)
        end
        false
      end

      def ban(address : String, duration : Time::Span = 1.hour) : Nil
        @banned_until[address] = Time.utc + duration
        disconnect(address)
      end

      def can_accept(direction : PeerDirection, address : String) : Bool
        return false if banned?(address)
        return false if @reputation.deprioritized?(address) && direction == PeerDirection::Inbound

        case direction
        when PeerDirection::Outbound, PeerDirection::Feeler
          outbound_count < MAX_OUTBOUND && @eclipse_guard.can_accept_peer(address)
        when PeerDirection::Inbound
          inbound_count < MAX_INBOUND && @eclipse_guard.can_accept_peer(address)
        end
      end

      def register(peer : Peer) : Bool
        return false if @peers.any? { |existing| existing.address == peer.address }

        @peers << peer
        @eclipse_guard.register_peer(peer.address)
        true
      end

      def disconnect(address : String) : Nil
        peer = @peers.find { |candidate| candidate.address == address }
        peer.try &.socket.try &.close
        @peers.reject! { |candidate| candidate.address == address }
        @eclipse_guard.unregister_peer(address)
      end

      def record_misbehavior(address : String, amount : Int32 = 1) : Nil
        if peer = @peers.find { |candidate| candidate.address == address }
          peer.mark_misbehavior(amount)
          @reputation.penalize(address)
          ban(address) if peer.banned?(BAN_THRESHOLD)
        end
      end

      def outbound_count : Int32
        @peers.count { |peer| peer.direction == PeerDirection::Outbound }
      end

      def inbound_count : Int32
        @peers.count { |peer| peer.direction == PeerDirection::Inbound }
      end

      def eclipse_status : EclipseStatus
        Eclipse.assess(peer_addresses)
      end

      def eviction_candidate : String?
        @eclipse_guard.eviction_candidate(peer_addresses)
      end
    end
  end
end
