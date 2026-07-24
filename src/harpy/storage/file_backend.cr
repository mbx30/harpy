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

      # v3 is an intentional consensus reset. Older envelopes and legacy bare
      # arrays must be reset instead of being interpreted under new rules.
      private def read_blocks(raw : String) : Array(Block)
        envelope = Envelope.from_json(raw)

        unless envelope.format_valid?
          Log.error { "chain_load_failed path=#{@path} reason=incompatible_format" }
          raise StorageError.new("stored chain format is incompatible with harpy-block-v3; reset chain data")
        end

        unless envelope.checksum_valid?
          Log.error { "chain_load_failed path=#{@path} reason=checksum_mismatch" }
          raise StorageError.new("stored chain failed checksum verification")
        end

        envelope.blocks
      rescue ex : StorageError
        raise ex
      rescue ex
        Log.error { "chain_load_failed path=#{@path} reason=incompatible_or_unparseable error=#{ex.message}" }
        raise StorageError.new("stored chain format is incompatible with harpy-block-v3; reset chain data")
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
