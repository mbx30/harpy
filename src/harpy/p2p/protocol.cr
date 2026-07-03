require "json"

module Harpy
  module P2p
    PROTOCOL_VERSION = 1

    enum MessageType
      Handshake
      HandshakeAck
      Inv
      GetBlock
      Block
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
      getter hash : String?
      getter block : JSON::Any?
      getter reason : String?

      def initialize(
        @type : String,
        @version : Int32? = nil,
        @genesis_hash : String? = nil,
        @height : Int32? = nil,
        @tip_hash : String? = nil,
        @hashes : Array(String)? = nil,
        @hash : String? = nil,
        @block : JSON::Any? = nil,
        @reason : String? = nil,
      )
      end

      def self.handshake(genesis_hash : String, height : Int32, tip_hash : String) : Message
        new("handshake", version: PROTOCOL_VERSION, genesis_hash: genesis_hash, height: height, tip_hash: tip_hash)
      end

      def self.handshake_ack(height : Int32, tip_hash : String) : Message
        new("handshake_ack", version: PROTOCOL_VERSION, height: height, tip_hash: tip_hash)
      end

      def self.inv(hashes : Array(String)) : Message
        new("inv", hashes: hashes)
      end

      def self.get_block(hash : String) : Message
        new("getblock", hash: hash)
      end

      def self.block_payload(block : Block) : Message
        new("block", block: JSON.parse(block.to_json))
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
        return nil unless socket.read(size_bytes) == 4

        size = IO::ByteFormat::BigEndian.decode(Int32, size_bytes)
        return nil if size <= 0 || size > Config.max_p2p_message_bytes

        payload = Bytes.new(size)
        return nil unless socket.read(payload) == size

        Message.from_json(String.new(payload))
      rescue
        nil
      end
    end
  end
end
