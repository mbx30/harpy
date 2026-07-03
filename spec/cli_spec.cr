require "./spec_helper"

describe Harpy::CLI do
  describe "verify-chain" do
    it "exits 0 and reports a summary for a valid chain" do
      path = File.tempname
      io = IO::Memory.new
      Harpy::Storage.save(Harpy::SpecHelpers.build_chain(3), path)

      begin
        code = Harpy::CLI.run(["verify-chain", "--path", path], io)
        code.should eq(0)
        io.to_s.should contain("chain valid")
        io.to_s.should contain("3 block")
      ensure
        File.delete?(path) if File.exists?(path)
      end
    end

    it "exits 1 when the chain file is corrupted" do
      path = File.tempname
      io = IO::Memory.new
      chain = Harpy::SpecHelpers.build_chain(2)
      Harpy::Storage.save(chain, path)

      begin
        File.write(path, File.read(path).sub(chain.blocks.first.hash[0..7], "deadbeef"))

        code = Harpy::CLI.run(["verify-chain", "--path", path], io)
        code.should eq(1)
        io.to_s.should contain("failed")
      ensure
        File.delete?(path) if File.exists?(path)
      end
    end

    it "exits 1 when no chain file exists" do
      path = File.tempname
      io = IO::Memory.new

      code = Harpy::CLI.run(["verify-chain", "--path", path], io)
      code.should eq(1)
      io.to_s.should contain("no chain found")
    end
  end

  describe "export-chain" do
    it "writes the chain blocks as JSON to --out and exits 0" do
      path = File.tempname
      out_path = File.tempname
      io = IO::Memory.new
      chain = Harpy::SpecHelpers.build_chain(2)
      Harpy::Storage.save(chain, path)

      begin
        code = Harpy::CLI.run(["export-chain", "--path", path, "--out", out_path], io)
        code.should eq(0)
        File.read(out_path).should eq(chain.blocks.to_json)
      ensure
        File.delete?(path) if File.exists?(path)
        File.delete?(out_path) if File.exists?(out_path)
      end
    end

    it "exits 1 when the source chain is missing" do
      path = File.tempname
      io = IO::Memory.new

      code = Harpy::CLI.run(["export-chain", "--path", path], io)
      code.should eq(1)
      io.to_s.should contain("no chain found")
    end
  end

  describe "dispatch" do
    it "exits 1 and shows usage on an unknown command" do
      io = IO::Memory.new

      code = Harpy::CLI.run(["frobnicate"], io)
      code.should eq(1)
      io.to_s.should contain("unknown command")
      io.to_s.should contain("Usage:")
    end

    it "exits 0 on help" do
      io = IO::Memory.new

      Harpy::CLI.run(["help"], io).should eq(0)
      io.to_s.should contain("Usage:")
    end
  end
end
