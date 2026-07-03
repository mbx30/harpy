require "json"
require "digest/sha256"
require "log"

module Harpy
  module Storage
    # Flat-file backend: a single JSON file holding a checksum envelope
    # (see `Storage::Envelope`). Writes are atomic (temp file + rename) and reads
    # verify the checksum before any Chain is constructed.
    class FileBackend < Backend
      Log = ::Log.for("harpy.storage")

      getter path : String

      def initialize(@path : String)
      end

      def load : Chain?
        return nil unless File.exists?(@path)

        Chain.new(read_blocks(File.read(@path)))
      end

      def save(chain : Chain) : Nil
        atomic_write(Envelope.wrap(chain.blocks).to_json)
      end

      # Parse the checksum envelope, falling back to the legacy bare-array format
      # for chain files written before the envelope existed.
      private def read_blocks(raw : String) : Array(Block)
        envelope = Envelope.from_json(raw)

        unless envelope.checksum_valid?
          Log.error { "chain_load_failed path=#{@path} reason=checksum_mismatch" }
          raise StorageError.new("stored chain failed checksum verification")
        end

        envelope.blocks
      rescue ex : StorageError
        raise ex
      rescue JSON::ParseException
        read_legacy_blocks(raw)
      end

      private def read_legacy_blocks(raw : String) : Array(Block)
        blocks = Array(Block).from_json(raw)
        Log.warn { "chain_load_legacy path=#{@path} reason=no_checksum_envelope" }
        blocks
      rescue JSON::ParseException
        Log.error { "chain_load_failed path=#{@path} reason=unparseable" }
        raise StorageError.new("stored chain file is not valid JSON")
      end

      # Write to a sibling temp file in the same directory, then rename over the
      # target. `File.rename` is atomic on the same filesystem (POSIX rename(2);
      # MoveFileEx with replace-if-exists on Windows), so a crash mid-write can
      # never leave a partially written chain file — readers see either the old
      # file or the fully written new one. The temp file is cleaned up on failure.
      private def atomic_write(content : String) : Nil
        Dir.mkdir_p(File.dirname(@path))
        tmp_path = "#{@path}.tmp"

        begin
          File.write(tmp_path, content)
          File.rename(tmp_path, @path)
        rescue ex
          File.delete?(tmp_path)
          raise ex
        end
      end
    end
  end
end
