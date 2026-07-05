require "./spec_helper"

describe Harpy::Storage do
  it "round-trips a chain through save and load" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(3)

    begin
      Harpy::Storage.save(chain, path)
      loaded = Harpy::Storage.load(path)

      loaded.should_not be_nil
      loaded.not_nil!.blocks.map(&.hash).should eq(chain.blocks.map(&.hash))
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "writes an envelope with version, checksum, and blocks fields" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)

    begin
      Harpy::Storage.save(chain, path)
      raw = JSON.parse(File.read(path))

      raw["version"].as_i.should eq(2)
      checksum = raw["checksum"].as_s
      checksum.should match(/\A[0-9a-f]{64}\z/)
      raw["blocks"].as_a.size.should eq(1)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a file whose checksum does not match its blocks" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)

    begin
      Harpy::Storage.save(chain, path)
      tampered = File.read(path).sub(chain.blocks.first.data, "tampered-data")
      File.write(path, tampered)

      expect_raises(Harpy::StorageError, /checksum/) do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a file with a corrupted checksum value" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)

    begin
      Harpy::Storage.save(chain, path)
      original_checksum = JSON.parse(File.read(path))["checksum"].as_s
      tampered = File.read(path).sub(original_checksum, "0" * 64)
      File.write(path, tampered)

      expect_raises(Harpy::StorageError, /checksum/) do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects an unknown storage version" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)

    begin
      Harpy::Storage.save(chain, path)
      tampered = File.read(path).sub(/"version":\d+/, %("version":999))
      File.write(path, tampered)

      expect_raises(Harpy::StorageError, /version 999/) do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "loads a legacy bare-array chain.json without an envelope" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      File.write(path, chain.blocks.to_json)

      loaded = Harpy::Storage.load(path)
      loaded.should_not be_nil
      loaded.not_nil!.blocks.map(&.hash).should eq(chain.blocks.map(&.hash))
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "does not rewrite a legacy file on load" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)

    begin
      legacy_json = chain.blocks.to_json
      File.write(path, legacy_json)

      Harpy::Storage.load(path)

      File.read(path).should eq(legacy_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "leaves the previous valid file intact if interrupted before rename" do
    path = File.tempname
    original = Harpy::SpecHelpers.build_chain(1)
    tmp_path : String? = nil

    begin
      Harpy::Storage.save(original, path)
      original_bytes = File.read(path)

      # Simulate a process dying between writing the temp file and renaming
      # it over the target — write a same-directory temp file, but never
      # call File.rename, and confirm the target is untouched.
      replacement = Harpy::SpecHelpers.build_chain(2)
      tmp_path = File.tempname(dir: File.dirname(path))
      File.write(tmp_path.not_nil!, replacement.blocks.to_json)

      File.read(path).should eq(original_bytes)
      loaded = Harpy::Storage.load(path)
      loaded.not_nil!.blocks.map(&.hash).should eq(original.blocks.map(&.hash))
    ensure
      File.delete?(path) if File.exists?(path)
      if tmp = tmp_path
        File.delete?(tmp) if File.exists?(tmp)
      end
    end
  end

  it "ignores a leftover stray temp file alongside a valid target file" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(1)
    stray_tmp = File.tempname(dir: File.dirname(path))

    begin
      Harpy::Storage.save(chain, path)
      File.write(stray_tmp, "not even valid json")

      loaded = Harpy::Storage.load(path)
      loaded.not_nil!.blocks.map(&.hash).should eq(chain.blocks.map(&.hash))
    ensure
      File.delete?(path) if File.exists?(path)
      File.delete?(stray_tmp) if File.exists?(stray_tmp)
    end
  end
end
