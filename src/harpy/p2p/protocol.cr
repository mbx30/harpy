require "json"

module Harpy
  module P2p
    PROTOCOL_VERSION    =  2
    MAX_HASHES_PER_INV  = 50
    MAX_BLOCKS_PER_SYNC = 50
    MAX_LOCATOR_HASHES  = 32

    def self.valid_hash?(hash : String) : Bool
      hash.size == 64 && hash.each_char.all? { |char| char.ascii_number? || ('a'..'f').includes?(char) }
    end

    def self.valid_inventory?(hashes : Array(String)) : Bool
      return false if hashes.empty? || hashes.size > MAX_HASHES_PER_INV
      return false unless hashes.uniq.size == hashes.size

      hashes.all? { |hash| valid_hash?(hash) }
    end

    def self.valid_locator?(hashes : Array(String)) : Bool
      return false if hashes.empty? || hashes.size > MAX_LOCATOR_HASHES
      return false unless hashes.uniq.size == hashes.size

      hashes.all? { |hash| valid_hash?(hash) }
    end

    enum MessageType
      Handshake
      HandshakeAck
      Inv
      GetBlock
      GetBlocksAfter
      GetBlocksByIndex
      Block
      SyncBegin
      SyncBlock
      SyncEnd
      Ping
      Pong
      Reject
    end

    struct Message
      include JSON::Serializable

      getter type : String
      getter version : Int32?
      getter genesis_hash : String?
      getter height : Int32?
      getter tip_hash : String?
      getter hashes : Array(String)?
      getter locator : Array(String)?
      getter hash : String?
      getter index : Int32?
      getter count : Int32?
      getter block : JSON::Any?
      getter reason : String?

      def initialize(
        @type : String,
        @version : Int32? = nil,
        @genesis_hash : String? = nil,
        @height : Int32? = nil,
        @tip_hash : String? = nil,
        @hashes : Array(String)? = nil,
        @locator : Array(String)? = nil,
        @hash : String? = nil,
        @index : Int32? = nil,
        @count : Int32? = nil,
        @block : JSON::Any? = nil,
        @reason : String? = nil,
      )
      end

      def self.handshake(genesis_hash : String, height : Int32, tip_hash : String) : Message
        new("handshake", version: PROTOCOL_VERSION, genesis_hash: genesis_hash, height: height, tip_hash: tip_hash)
      end

      def self.handshake_ack(genesis_hash : String, height : Int32, tip_hash : String) : Message
        new("handshake_ack", version: PROTOCOL_VERSION, genesis_hash: genesis_hash, height: height, tip_hash: tip_hash)
      end

      def self.inv(hashes : Array(String)) : Message
        new("inv", hashes: hashes)
      end

      def self.get_block(hash : String) : Message
        new("getblock", hash: hash)
      end

      def self.get_blocks_after(locator : Array(String), count : Int32) : Message
        new("getblocksafter", locator: locator, count: count)
      end

      def self.get_blocks_by_index(index : Int32, count : Int32) : Message
        new("getblocksbyindex", index: index, count: count)
      end

      def self.block_payload(block : Block) : Message
        new("block", block: JSON.parse(block.to_json))
      end

      def self.sync_begin(index : Int32, common_hash : String) : Message
        new("syncbegin", index: index, hash: common_hash)
      end

      def self.sync_block_payload(block : Block) : Message
        new("syncblock", block: JSON.parse(block.to_json))
      end

      def self.sync_end(index : Int32) : Message
        new("syncend", index: index)
      end

      def self.ping : Message
        new("ping")
      end

      def self.pong : Message
        new("pong")
      end

      def self.reject(reason : String) : Message
        new("reject", reason: reason)
      end
    end

    module Wire
      extend self

      def write(socket : IO, message : Message) : Nil
        payload = message.to_json
        bytes = payload.to_slice
        socket.write_bytes(bytes.size, IO::ByteFormat::BigEndian)
        socket.write(bytes)
        socket.flush
      end

      def read(socket : IO) : Message?
        size_bytes = Bytes.new(4)
        socket.read_fully(size_bytes)

        size = IO::ByteFormat::BigEndian.decode(Int32, size_bytes)
        return nil if size <= 0 || size > Config.max_p2p_message_bytes

        payload = Bytes.new(size)
        socket.read_fully(payload)

        Message.from_json(String.new(payload))
      rescue
        nil
      end
    end
  end
end
