require "socket"
require "./protocol"

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
      getter identity : String
      getter socket : TCPSocket?
      getter direction : PeerDirection
      getter anchor : Bool
      property handshake_complete : Bool
      property misbehavior_score : Int32
      property remote_height : Int32
      property remote_tip_hash : String
      property sync_next_index : Int32

      def initialize(
        @id : String,
        @address : String,
        @identity : String,
        @socket : TCPSocket? = nil,
        @direction : PeerDirection = PeerDirection::Inbound,
        @handshake_complete : Bool = false,
        @misbehavior_score : Int32 = 0,
        @anchor : Bool = false,
        @remote_height : Int32 = 0,
        @remote_tip_hash : String = "",
        @sync_next_index : Int32 = 0,
      )
        @write_mutex = Mutex.new
      end

      def send_message(message : Message) : Nil
        @write_mutex.synchronize do
          @socket.try { |socket| Wire.write(socket, message) }
        end
      rescue IO::Error
      end

      def mark_misbehavior(amount : Int32 = 1) : Nil
        @misbehavior_score += amount
      end

      def banned?(threshold : Int32) : Bool
        @misbehavior_score >= threshold
      end
    end

    class PeerManager
      MAX_OUTBOUND  =  8
      MAX_INBOUND   = 32
      BAN_THRESHOLD = 10

      def initialize(
        @eclipse_guard : EclipseGuard = EclipseGuard.new,
        @reputation : Reputation = Reputation.new,
      )
        @peers = [] of Peer
        @banned_until = {} of String => Time
        @misbehavior_scores = Hash(String, Int32).new(0)
        @mutex = Mutex.new
      end

      def peers : Array(Peer)
        @mutex.synchronize { @peers.dup }
      end

      def banned_until : Hash(String, Time)
        @mutex.synchronize { @banned_until.dup }
      end

      def reputation : Reputation
        @reputation
      end

      def eclipse_guard : EclipseGuard
        @eclipse_guard
      end

      def peer_addresses : Array(String)
        @mutex.synchronize { @peers.map(&.identity) }
      end

      def banned?(identity : String) : Bool
        @mutex.synchronize { banned_unlocked?(identity) }
      end

      private def banned_unlocked?(identity : String) : Bool
        if until_time = @banned_until[identity]?
          if Time.utc < until_time
            return true
          end
          @banned_until.delete(identity)
          @misbehavior_scores.delete(identity)
        end
        false
      end

      def ban(identity : String, duration : Time::Span = 1.hour) : Nil
        sockets = @mutex.synchronize do
          @banned_until[identity] = Time.utc + duration
          remove_identity_unlocked(identity)
        end
        sockets.each(&.close)
      end

      def can_accept(direction : PeerDirection, identity : String, is_anchor : Bool = false) : Bool
        @mutex.synchronize { can_accept_unlocked?(direction, identity, is_anchor) }
      end

      private def can_accept_unlocked?(direction : PeerDirection, identity : String, is_anchor : Bool = false) : Bool
        return false if banned_unlocked?(identity)
        return false if @reputation.deprioritized?(identity) && direction == PeerDirection::Inbound

        case direction
        when PeerDirection::Outbound, PeerDirection::Feeler
          outbound_count_unlocked < MAX_OUTBOUND && @eclipse_guard.can_accept_peer(identity, is_anchor)
        when PeerDirection::Inbound
          inbound_count_unlocked < MAX_INBOUND && @eclipse_guard.can_accept_peer(identity, is_anchor)
        else
          false
        end
      end

      def register(peer : Peer) : Bool
        @mutex.synchronize do
          return false unless can_accept_unlocked?(peer.direction, peer.identity, peer.anchor)
          return false if @peers.any? { |existing| existing.id == peer.id }

          @peers << peer
          @eclipse_guard.register_peer(peer.identity)
          true
        end
      end

      def disconnect(id : String) : Nil
        socket = @mutex.synchronize do
          peer = @peers.find { |candidate| candidate.id == id }
          if peer
            @peers.delete(peer)
            @eclipse_guard.unregister_peer(peer.identity)
            peer.socket
          end
        end
        socket.try &.close
      end

      def record_misbehavior(identity : String, amount : Int32 = 1) : Nil
        sockets = [] of TCPSocket
        @mutex.synchronize do
          matching = @peers.select { |candidate| candidate.identity == identity }
          matching.each(&.mark_misbehavior(amount))
          @misbehavior_scores[identity] += amount
          @reputation.penalize(identity)

          if @misbehavior_scores[identity] >= BAN_THRESHOLD
            @banned_until[identity] = Time.utc + 1.hour
            sockets = remove_identity_unlocked(identity)
          end
        end
        sockets.each(&.close)
      end

      def outbound_count : Int32
        @mutex.synchronize { outbound_count_unlocked }
      end

      def inbound_count : Int32
        @mutex.synchronize { inbound_count_unlocked }
      end

      def eclipse_status : EclipseStatus
        Eclipse.assess(peer_addresses)
      end

      def eviction_candidate : String?
        addresses, anchors = @mutex.synchronize do
          {@peers.map(&.identity), @peers.select(&.anchor).map(&.identity)}
        end
        @eclipse_guard.eviction_candidate(addresses, anchors)
      end

      private def outbound_count_unlocked : Int32
        @peers.count do |peer|
          peer.direction == PeerDirection::Outbound || peer.direction == PeerDirection::Feeler
        end
      end

      private def inbound_count_unlocked : Int32
        @peers.count { |peer| peer.direction == PeerDirection::Inbound }
      end

      private def remove_identity_unlocked(identity : String) : Array(TCPSocket)
        removed = @peers.select { |peer| peer.identity == identity }
        removed.each do |peer|
          @peers.delete(peer)
          @eclipse_guard.unregister_peer(peer.identity)
        end
        removed.compact_map(&.socket)
      end
    end
  end
end
