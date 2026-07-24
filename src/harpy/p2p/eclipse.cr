module Harpy
  module P2p
    # Lightweight eclipse-risk detection: monitors peer diversity by /16 subnet.
    struct EclipseStatus
      getter at_risk : Bool
      getter distinct_subnets : Int32
      getter total_peers : Int32
      getter dominant_subnet : String?
      getter dominant_share : Float64

      def initialize(
        @at_risk : Bool,
        @distinct_subnets : Int32,
        @total_peers : Int32,
        @dominant_subnet : String? = nil,
        @dominant_share : Float64 = 0.0,
      )
      end
    end

    module Eclipse
      extend self

      MIN_DISTINCT_SUBNETS =    2
      MAX_SUBNET_SHARE     = 0.75

      def subnet_16(address : String) : String
        host = address.includes?(':') ? address.split(':').first : address
        parts = host.split('.')
        return host if parts.size != 4

        "#{parts[0]}.#{parts[1]}.0.0/16"
      end

      def assess(peer_addresses : Array(String)) : EclipseStatus
        return EclipseStatus.new(false, 0, 0) if peer_addresses.empty?

        counts = Hash(String, Int32).new
        peer_addresses.each do |addr|
          bucket = subnet_16(addr)
          counts[bucket] = (counts[bucket]? || 0) + 1
        end

        total = peer_addresses.size
        dominant = counts.max_by { |_, count| count }
        dominant_subnet, dominant_count = dominant
        share = dominant_count.to_f / total

        at_risk = counts.size < MIN_DISTINCT_SUBNETS || share > MAX_SUBNET_SHARE

        EclipseStatus.new(
          at_risk: at_risk,
          distinct_subnets: counts.size.to_i32,
          total_peers: total.to_i32,
          dominant_subnet: dominant_subnet,
          dominant_share: share,
        )
      end
    end

    # Bitcoin-style eclipse countermeasures: bucketing, anchors, feelers, test-before-evict.
    class EclipseGuard
      MAX_PER_SUBNET    =   2
      FEELER_INTERVAL_S = 120
      ANCHOR_SLOTS      =   2

      getter anchor_peers : Array(String)

      def initialize(anchor_peers : Array(String) = [] of String)
        @anchor_peers = anchor_peers.first(ANCHOR_SLOTS).map do |address|
          address.includes?(':') ? address.split(':').first : address
        end
        @subnet_counts = Hash(String, Int32).new
        @last_feeler_at = Time.utc
      end

      def can_accept_peer(address : String, is_anchor : Bool = false) : Bool
        return true if is_anchor || @anchor_peers.includes?(address)

        bucket = Eclipse.subnet_16(address)
        (@subnet_counts[bucket]? || 0) < MAX_PER_SUBNET
      end

      def register_peer(address : String) : Nil
        bucket = Eclipse.subnet_16(address)
        @subnet_counts[bucket] = (@subnet_counts[bucket]? || 0) + 1
      end

      def unregister_peer(address : String) : Nil
        bucket = Eclipse.subnet_16(address)
        if count = @subnet_counts[bucket]?
          if count <= 1
            @subnet_counts.delete(bucket)
          else
            @subnet_counts[bucket] = count - 1
          end
        end
      end

      def should_probe_feeler? : Bool
        (Time.utc - @last_feeler_at).total_seconds >= FEELER_INTERVAL_S
      end

      def mark_feeler_probe : Nil
        @last_feeler_at = Time.utc
      end

      # Test-before-evict: prefer evicting a non-anchor peer from an over-represented /16.
      def eviction_candidate(peer_addresses : Array(String), exempt : Array(String) = [] of String) : String?
        candidates = peer_addresses.reject { |addr| exempt.includes?(addr) || @anchor_peers.includes?(addr) }
        return nil if candidates.empty?

        counts = Hash(String, Int32).new
        candidates.each do |addr|
          bucket = Eclipse.subnet_16(addr)
          counts[bucket] = (counts[bucket]? || 0) + 1
        end

        over_bucket = counts.max_by { |_, count| count }.first
        candidates.find { |addr| Eclipse.subnet_16(addr) == over_bucket }
      end
    end
  end
end
