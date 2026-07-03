require "option_parser"
require "./config"
require "./chain"
require "./storage"
require "./server"

module Harpy
  # Command-line entry point. With no arguments it boots the HTTP server
  # (the default tutorial behavior); subcommands are thin, scriptable wrappers
  # over `Storage.load` and `Chain#valid?` that exit non-zero on failure.
  module CLI
    extend self

    def run(args : Array(String), io : IO = STDOUT) : Int32
      case args.first?
      when nil
        Server.start
        0
      when "export-chain"
        export_chain(args[1..], io)
      when "verify-chain"
        verify_chain(args[1..], io)
      when "help", "-h", "--help"
        print_usage(io)
        0
      else
        io.puts "unknown command: #{args.first}"
        print_usage(io)
        1
      end
    end

    # export-chain --path <file> [--out <file>]: read the chain and write its
    # blocks as JSON to --out (or stdout).
    private def export_chain(args : Array(String), io : IO) : Int32
      path = Config.storage_path
      out_path = nil

      OptionParser.parse(args) do |parser|
        parser.on("--path PATH", "Chain file to read (default: #{Config.storage_path})") { |v| path = v }
        parser.on("--out FILE", "Write JSON here (default: stdout)") { |v| out_path = v }
      end

      chain = Storage.load(path)
      unless chain
        io.puts "no chain found at #{path}"
        return 1
      end

      json = chain.blocks.to_json
      if destination = out_path
        File.write(destination, json)
        io.puts "exported #{chain.height} block(s) to #{destination}"
      else
        io.puts json
      end
      0
    rescue ex : StorageError
      io.puts "export failed: #{ex.message}"
      1
    end

    # verify-chain --path <file>: load and fully validate the chain. Prints a
    # summary and exits 0 if valid, 1 otherwise (corruption or invalid chain).
    private def verify_chain(args : Array(String), io : IO) : Int32
      path = Config.storage_path

      OptionParser.parse(args) do |parser|
        parser.on("--path PATH", "Chain file to verify (default: #{Config.storage_path})") { |v| path = v }
      end

      chain = Storage.load(path)
      unless chain
        io.puts "no chain found at #{path}"
        return 1
      end

      if chain.valid?
        io.puts "chain valid: #{chain.height} block(s), work=#{chain.cumulative_work}"
        0
      else
        io.puts "chain INVALID: #{path}"
        1
      end
    rescue ex : StorageError
      io.puts "verify failed: #{ex.message}"
      1
    end

    private def print_usage(io : IO) : Nil
      io.puts <<-USAGE
      harpy — Crystal proof-of-work blockchain

      Usage:
        harpy                                   Start the HTTP server (default)
        harpy export-chain --path F [--out G]   Export chain blocks as JSON
        harpy verify-chain --path F             Validate a chain file (exit 1 on failure)
        harpy help                              Show this message
      USAGE
    end
  end
end
