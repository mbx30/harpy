require "log"
require "socket"
require "./protocol"
require "./orphan_pool"
require "./peer_manager"
require "./reputation"
require "./eclipse"
require "../chain"
require "../storage"

module Harpy
  module P2p
    class Network
      Log = ::Log.for("harpy.p2p")

      HANDSHAKE_TIMEOUT     = 5.seconds
      FRAME_READ_TIMEOUT    = 60.seconds
      WRITE_TIMEOUT         = 10.seconds
      OUTBOUND_RETRY_DELAY  = 1.second
      SYNC_PERSIST_INTERVAL = 10

      getter orphan_pool : OrphanPool
      getter peer_manager : PeerManager
      getter chain : Chain
      getter port : Int32
      getter running : Bool

      def initialize(
        @chain : Chain,
        @storage_path : String,
        @port : Int32 = Config.p2p_port,
        @mutex : Mutex = Mutex.new,
        @handshake_timeout : Time::Span = HANDSHAKE_TIMEOUT,
        @frame_read_timeout : Time::Span = FRAME_READ_TIMEOUT,
        @write_timeout : Time::Span = WRITE_TIMEOUT,
        @outbound_retry_delay : Time::Span = OUTBOUND_RETRY_DELAY,
      )
        @orphan_pool = OrphanPool.new
        @peer_manager = PeerManager.new
        @sync_chains = {} of String => Chain
        @sync_locators = {} of String => Array(String)
        @server = nil
        @running = false
      end

      def start : Nil
        return if @running

        @running = true
        spawn { accept_loop }
        Config.p2p_peers.each { |address| spawn { maintain_outbound(address) } }
      end

      def stop : Nil
        @running = false
        @server.try &.close
        @peer_manager.peers.each { |peer| peer.socket.try &.close }
      end

      def broadcast_block(block : Block, except_peer_id : String? = nil) : Nil
        message = Message.inv([block.hash])
        @peer_manager.peers.each do |peer|
          next if peer.id == except_peer_id
          next if @peer_manager.reputation.deprioritized?(peer.identity)

          peer.send_message(message)
        end
      end

      def handle_incoming_block(
        block : Block,
        peer_identity : String,
        persist : Bool = true,
        source_peer_id : String? = nil,
      ) : Chain::BlockAcceptResult
        result = @mutex.synchronize do
          accept = @chain.accept_block!(block, @orphan_pool)
          case accept
          when Chain::BlockAcceptResult::Connected, Chain::BlockAcceptResult::Reorganized
            Storage.save(@chain, @storage_path) if persist
            @peer_manager.reputation.reward(peer_identity)
          when Chain::BlockAcceptResult::Rejected
            @peer_manager.record_misbehavior(peer_identity, 2)
          end
          accept
        end

        if result.in?({Chain::BlockAcceptResult::Connected, Chain::BlockAcceptResult::Reorganized, Chain::BlockAcceptResult::Orphaned})
          broadcast_block(block, except_peer_id: source_peer_id)
        end

        result
      end

      private def accept_loop : Nil
        @server = TCPServer.new("0.0.0.0", @port)
        Log.info { "p2p_listening port=#{@port}" }

        while @running
          begin
            socket = @server.not_nil!.accept
            id, identity = socket_identity(socket)
            spawn { handle_connection(socket, id, identity, PeerDirection::Inbound) }
          rescue ex
            break unless @running
            Log.warn { "p2p_accept_error error=#{ex.message}" }
          end
        end
      end

      private def connect_outbound(address : String) : Nil
        host, port = parse_host_port(address)
        socket = TCPSocket.new(host, port)
        id, identity = socket_identity(socket)
        is_anchor = Config.anchor_peers.includes?(address)
        handle_connection(socket, id, identity, PeerDirection::Outbound, is_anchor)
      rescue ex
        Log.warn { "p2p_connect_failed peer=#{address} error=#{ex.message}" }
      end

      private def maintain_outbound(address : String) : Nil
        while @running
          connect_outbound(address)
          break unless @running

          sleep @outbound_retry_delay
        end
      end

      private def handle_connection(
        socket : TCPSocket,
        id : String,
        identity : String,
        direction : PeerDirection,
        is_anchor : Bool = false,
      ) : Nil
        socket.read_timeout = @handshake_timeout
        socket.write_timeout = @write_timeout
        peer = Peer.new(id, id, identity, socket, direction, anchor: is_anchor)
        unless @peer_manager.register(peer)
          socket.close
          return
        end

        begin
          unless perform_handshake(peer, direction)
            @peer_manager.record_misbehavior(identity)
            return
          end

          peer.handshake_complete = true
          start_sync(peer)
          socket.read_timeout = @frame_read_timeout

          while @running
            message = Wire.read(socket)
            break unless message
            handle_message(peer, message)
          end
        ensure
          @mutex.synchronize do
            @sync_chains.delete(id)
            @sync_locators.delete(id)
          end
          @peer_manager.disconnect(id)
          socket.close unless socket.closed?
        end
      end

      private def perform_handshake(peer : Peer, direction : PeerDirection) : Bool
        socket = peer.socket
        return false unless socket

        case direction
        when PeerDirection::Outbound
          send_handshake(peer)
          incoming = Wire.read(socket)
          return false unless incoming

          case incoming.type
          when "handshake"
            return false unless compatible_handshake?(incoming)
            record_remote_handshake(peer, incoming)
            send_handshake_ack(peer)
            true
          when "handshake_ack"
            return false unless compatible_handshake?(incoming)

            record_remote_handshake(peer, incoming)
            true
          else
            false
          end
        else
          incoming = Wire.read(socket)
          return false unless incoming
          return false unless incoming.type == "handshake"
          return false unless compatible_handshake?(incoming)

          record_remote_handshake(peer, incoming)
          send_handshake_ack(peer)
          true
        end
      end

      private def send_handshake(peer : Peer) : Nil
        peer.send_message(Message.handshake(@chain.genesis_hash, @chain.height, @chain.tip.hash))
      end

      private def send_handshake_ack(peer : Peer) : Nil
        peer.send_message(Message.handshake_ack(@chain.genesis_hash, @chain.height, @chain.tip.hash))
      end

      # Negotiate a common ancestor before streaming forward. A dedicated
      # candidate chain holds deep forks, so the bounded orphan pool is never
      # used as long-range synchronization storage.
      private def start_sync(peer : Peer) : Nil
        local_tip = @mutex.synchronize { @chain.tip.hash }
        return if peer.remote_tip_hash == local_tip

        locator = block_locator
        @mutex.synchronize { @sync_locators[peer.id] = locator }
        peer.send_message(Message.get_blocks_after(locator, MAX_BLOCKS_PER_SYNC))
      end

      private def request_sync_range(peer : Peer, index : Int32) : Nil
        return if index >= peer.remote_height

        count = Math.min(MAX_BLOCKS_PER_SYNC, peer.remote_height - index)
        peer.sync_next_index = index
        peer.send_message(Message.get_blocks_by_index(index, count))
      end

      private def handle_message(peer : Peer, message : Message) : Nil
        identity = peer.identity
        case message.type
        when "inv"
          hashes = message.hashes || [] of String
          unless P2p.valid_inventory?(hashes) && @peer_manager.reputation.record_inv(identity, hashes.size)
            @peer_manager.record_misbehavior(identity, 2)
            peer.send_message(Message.reject("invalid or rate-limited inventory"))
            return
          end

          hashes.each do |hash|
            next if @chain.has_block?(hash)

            peer.send_message(Message.get_block(hash))
          end
        when "getblock"
          hash = message.hash
          unless hash && P2p.valid_hash?(hash)
            @peer_manager.record_misbehavior(identity)
            peer.send_message(Message.reject("invalid block hash"))
            return
          end

          block = @chain.block_by_hash(hash) || @orphan_pool.get(hash)
          if block
            response = Message.block_payload(block)
            if record_block_response(peer, [response])
              peer.send_message(response)
            else
              peer.send_message(Message.reject("block response rate limit exceeded"))
            end
          else
            peer.send_message(Message.reject("block not found"))
          end
        when "getblocksafter"
          locator = message.locator || [] of String
          count = message.count
          unless P2p.valid_locator?(locator) && count && count.in?(1..MAX_BLOCKS_PER_SYNC)
            @peer_manager.record_misbehavior(identity)
            peer.send_message(Message.reject("invalid block locator"))
            return
          end

          common, blocks = @mutex.synchronize do
            ancestor = locator.compact_map { |hash| @chain.block_by_hash(hash) }.first?
            if ancestor
              start = ancestor.index + 1
              {ancestor, @chain.blocks[start, count]? || [] of Block}
            else
              {nil, [] of Block}
            end
          end
          unless common
            @peer_manager.record_misbehavior(identity)
            peer.send_message(Message.reject("no common ancestor"))
            return
          end

          send_sync_batch(peer, common.index + 1, blocks, common.hash)
        when "getblocksbyindex"
          index = message.index
          count = message.count
          unless index && index >= 0 && count && count.in?(1..MAX_BLOCKS_PER_SYNC)
            @peer_manager.record_misbehavior(identity)
            peer.send_message(Message.reject("invalid block range"))
            return
          end

          blocks = @mutex.synchronize { @chain.blocks[index, count]? || [] of Block }
          if blocks.empty?
            peer.send_message(Message.reject("block not found"))
          else
            send_sync_batch(peer, index, blocks)
          end
        when "syncbegin"
          begin_sync(peer, message)
        when "syncblock"
          json = message.block
          return unless json

          handle_sync_block(peer, Block.from_json(json))
        when "syncend"
          finish_sync_batch(peer, message)
        when "block"
          json = message.block
          return unless json

          block = Block.from_json(json)
          result = handle_incoming_block(block, identity, source_peer_id: peer.id)
          if result == Chain::BlockAcceptResult::Orphaned
            missing_parent = @mutex.synchronize do
              !@chain.has_block?(block.prev_hash) && !@orphan_pool.get(block.prev_hash)
            end
            peer.send_message(Message.get_block(block.prev_hash)) if missing_parent
          end
        when "ping"
          peer.send_message(Message.pong)
        end
      rescue ex
        Log.warn { "p2p_message_error peer=#{peer.address} error=#{ex.message}" }
        @peer_manager.record_misbehavior(peer.identity)
      end

      private def send_sync_batch(
        peer : Peer,
        start_index : Int32,
        blocks : Array(Block),
        common_hash : String? = nil,
      ) : Nil
        messages = [] of Message
        messages << Message.sync_begin(start_index, common_hash) if common_hash

        block_messages = [] of Message
        byte_count = messages.sum(0) { |message| framed_size(message) }
        blocks.each do |block|
          message = Message.sync_block_payload(block)
          break if byte_count + framed_size(message) > Reputation::MAX_BLOCK_BYTES_PER_REQUEST

          block_messages << message
          byte_count += framed_size(message)
        end

        end_message = Message.sync_end(start_index + block_messages.size)
        messages.concat(block_messages)
        messages << end_message

        unless record_block_response(peer, messages)
          peer.send_message(Message.reject("block response rate limit exceeded"))
          return
        end

        messages.each { |message| peer.send_message(message) }
      end

      private def record_block_response(peer : Peer, messages : Array(Message)) : Bool
        byte_count = messages.sum(0) { |message| framed_size(message) }
        @peer_manager.reputation.record_block_response(peer.identity, byte_count)
      end

      private def framed_size(message : Message) : Int32
        message.to_json.bytesize + 4
      end

      private def begin_sync(peer : Peer, message : Message) : Nil
        index = message.index
        common_hash = message.hash
        unless index && index > 0 && common_hash && P2p.valid_hash?(common_hash)
          @peer_manager.record_misbehavior(peer.identity)
          return
        end

        unless @peer_manager.reputation.record_sync_control(peer.identity)
          @peer_manager.record_misbehavior(peer.identity)
          return
        end

        prefix = @mutex.synchronize do
          requested_locator = @sync_locators.delete(peer.id)
          next nil unless requested_locator && requested_locator.includes?(common_hash)

          common_index = @chain.find_block_index_by_hash(common_hash)
          next nil unless common_index && common_index + 1 == index

          @chain.blocks[0...index].dup
        end
        unless prefix
          @peer_manager.record_misbehavior(peer.identity)
          return
        end

        candidate = Chain.new(prefix)
        initialized = @mutex.synchronize do
          common_index = @chain.find_block_index_by_hash(common_hash)
          next false unless common_index && common_index + 1 == index

          @sync_chains[peer.id] = candidate
          peer.sync_next_index = index
          true
        end
        @peer_manager.record_misbehavior(peer.identity) unless initialized
      end

      private def handle_sync_block(peer : Peer, block : Block) : Nil
        accepted = false
        connected = false

        @mutex.synchronize do
          sync_chain = @sync_chains[peer.id]?
          next unless sync_chain
          next unless block.index == sync_chain.height
          next unless sync_chain.append!(block)

          accepted = true
          if @chain.tip.hash == block.prev_hash
            connected = @chain.append!(block)
          elsif sync_chain.cumulative_work > @chain.cumulative_work
            connected = @chain.reorg_to!(sync_chain.blocks)
          end

          if connected && @chain.height % SYNC_PERSIST_INTERVAL == 0
            Storage.save(@chain, @storage_path)
          end
        end

        unless accepted
          @mutex.synchronize { @sync_chains.delete(peer.id) }
          @peer_manager.record_misbehavior(peer.identity, 2)
          peer.send_message(Message.reject("invalid sync block"))
          return
        end

        @peer_manager.reputation.reward(peer.identity)
        broadcast_block(block, except_peer_id: peer.id) if connected
      end

      private def finish_sync_batch(peer : Peer, message : Message) : Nil
        index = message.index
        valid = @mutex.synchronize do
          sync_chain = @sync_chains[peer.id]?
          next false unless index && sync_chain && index == sync_chain.height

          if @chain.tip.hash == sync_chain.tip.hash
            Storage.save(@chain, @storage_path)
          end
          true
        end

        unless valid
          @peer_manager.record_misbehavior(peer.identity)
          return
        end

        if index.not_nil! < peer.remote_height
          request_sync_range(peer, index.not_nil!)
        else
          @mutex.synchronize { @sync_chains.delete(peer.id) }
        end
      end

      private def compatible_handshake?(message : Message) : Bool
        height = message.height
        tip_hash = message.tip_hash
        return false unless height && tip_hash

        message.version == PROTOCOL_VERSION &&
          message.genesis_hash == @chain.genesis_hash &&
          height > 0 &&
          P2p.valid_hash?(tip_hash)
      end

      private def record_remote_handshake(peer : Peer, message : Message) : Nil
        peer.remote_height = message.height.not_nil!
        peer.remote_tip_hash = message.tip_hash.not_nil!
      end

      private def block_locator : Array(String)
        @mutex.synchronize do
          hashes = [] of String
          index = @chain.height - 1
          step = 1

          while index > 0 && hashes.size < MAX_LOCATOR_HASHES - 1
            hashes << @chain.blocks[index].hash
            step *= 2 if hashes.size >= 10
            index = Math.max(0, index - step)
          end

          hashes << @chain.genesis_hash unless hashes.includes?(@chain.genesis_hash)
          hashes
        end
      end

      private def socket_identity(socket : TCPSocket) : Tuple(String, String)
        remote = socket.remote_address
        if remote.is_a?(Socket::IPAddress)
          {remote.to_s, remote.address}
        else
          value = remote.try(&.to_s) || "unknown"
          {value, value}
        end
      end

      private def parse_host_port(address : String) : Tuple(String, Int32)
        if address.includes?(':')
          host, port = address.split(':', limit: 2)
          {host, port.to_i32}
        else
          {address, @port}
        end
      end
    end
  end
end
