require "json"

module Harpy
  class StorageError < Exception; end

  module Storage
    extend self

    DEFAULT_PATH = "data/chain.json"

    def load(path : String = DEFAULT_PATH) : Chain?
      return nil unless File.exists?(path)

      blocks = Array(Block).from_json(File.read(path))
      Chain.new(blocks)
    end

    def save(chain : Chain, path : String = DEFAULT_PATH) : Nil
      Dir.mkdir_p(File.dirname(path))
      File.write(path, chain.blocks.to_json)
    end

    def load_or_genesis(path : String = DEFAULT_PATH, verbose : Bool = false) : Chain
      if chain = load(path)
        raise StorageError.new("stored chain failed validation") unless chain.valid?

        chain
      else
        chain = Chain.genesis_chain(verbose: verbose)
        save(chain, path)
        chain
      end
    end
  end
end
