require "./spec_helper"

describe Harpy::Config do
  it "uses DEFAULT_DIFFICULTY when HARPY_DIFFICULTY is unset" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", nil) do
      Harpy::Config.genesis_difficulty.should eq(Harpy::Block::DEFAULT_DIFFICULTY)
    end
  end

  it "reads genesis difficulty from HARPY_DIFFICULTY" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "1") do
      Harpy::Config.genesis_difficulty.should eq(1)
    end
  end

  it "falls back when HARPY_DIFFICULTY is invalid" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "-1") do
      Harpy::Config.genesis_difficulty.should eq(Harpy::Block::DEFAULT_DIFFICULTY)
    end
  end

  it "exposes request and block transaction size limits" do
    Harpy::Config.max_request_body_bytes.should eq(64 * 1024)
    Harpy::Config.max_block_transactions_bytes.should eq(32 * 1024)
    Harpy::Config.max_block_transactions_bytes.should be < Harpy::Config.max_request_body_bytes
  end

  it "uses the default storage path when HARPY_DATA_DIR is unset" do
    Harpy::SpecHelpers.with_env("HARPY_DATA_DIR", nil) do
      Harpy::Config.storage_path.should eq(Harpy::Storage::DEFAULT_PATH)
    end
  end

  it "treats HARPY_DATA_DIR as a directory" do
    Harpy::SpecHelpers.with_env("HARPY_DATA_DIR", "custom-data") do
      # File.join uses the platform separator ("\\" on Windows).
      Harpy::Config.storage_path.should eq(File.join("custom-data", "chain.json"))
    end
  end

  it "treats HARPY_DATA_DIR ending in .json as a file path" do
    Harpy::SpecHelpers.with_env("HARPY_DATA_DIR", "custom-data/my-chain.json") do
      Harpy::Config.storage_path.should eq("custom-data/my-chain.json")
    end
  end

  it "uses default rate limit settings when env is unset" do
    Harpy::SpecHelpers.with_env("HARPY_RATE_LIMIT", nil) do
      Harpy::SpecHelpers.with_env("HARPY_RATE_LIMIT_WINDOW", nil) do
        Harpy::Config.rate_limit_max.should eq(Harpy::Config::DEFAULT_RATE_LIMIT_MAX)
        Harpy::Config.rate_limit_window_seconds.should eq(Harpy::Config::DEFAULT_RATE_LIMIT_WINDOW_S)
      end
    end
  end

  it "reads rate limit settings from env" do
    Harpy::SpecHelpers.with_env("HARPY_RATE_LIMIT", "5") do
      Harpy::SpecHelpers.with_env("HARPY_RATE_LIMIT_WINDOW", "30") do
        Harpy::Config.rate_limit_max.should eq(5)
        Harpy::Config.rate_limit_window_seconds.should eq(30)
      end
    end
  end

  it "binds to loopback by default" do
    Harpy::SpecHelpers.with_env("HARPY_BIND_HOST", nil) do
      Harpy::Config.bind_host.should eq("127.0.0.1")
    end
  end

  it "reads bind host from HARPY_BIND_HOST" do
    Harpy::SpecHelpers.with_env("HARPY_BIND_HOST", "0.0.0.0") do
      Harpy::Config.bind_host.should eq("0.0.0.0")
    end
  end

  it "allows writes when HARPY_API_KEY is unset" do
    request = HTTP::Request.new("POST", "/new-block")
    Harpy::SpecHelpers.with_env("HARPY_API_KEY", nil) do
      Harpy::Config.write_authorized?(request).should be_true
    end
  end

  it "accepts Authorization Bearer for write auth" do
    request = HTTP::Request.new("POST", "/new-block")
    request.headers["Authorization"] = "Bearer secret-key"

    Harpy::Config.write_authorized?(request, "secret-key").should be_true
  end

  it "accepts X-API-Key for write auth" do
    request = HTTP::Request.new("POST", "/new-block")
    request.headers["X-API-Key"] = "secret-key"

    Harpy::Config.write_authorized?(request, "secret-key").should be_true
  end

  it "rejects missing credentials when HARPY_API_KEY is set" do
    request = HTTP::Request.new("POST", "/new-block")

    Harpy::Config.write_authorized?(request, "secret-key").should be_false
  end

  it "rejects a wrong Bearer token" do
    request = HTTP::Request.new("POST", "/new-block")
    request.headers["Authorization"] = "Bearer wrong-key"

    Harpy::Config.write_authorized?(request, "secret-key").should be_false
  end

  it "rejects a wrong X-API-Key" do
    request = HTTP::Request.new("POST", "/new-block")
    request.headers["X-API-Key"] = "wrong-key"

    Harpy::Config.write_authorized?(request, "secret-key").should be_false
  end

  it "rejects a token that is a prefix of the key (length-safe comparison)" do
    request = HTTP::Request.new("POST", "/new-block")
    request.headers["X-API-Key"] = "secret"

    Harpy::Config.write_authorized?(request, "secret-key").should be_false
  end
end

describe "Harpy::Config.trust_proxy?" do
  it "defaults to false" do
    Harpy::SpecHelpers.with_env("HARPY_TRUST_PROXY", nil) do
      Harpy::Config.trust_proxy?.should be_false
    end
  end

  it "is true for common truthy values" do
    {"1", "true", "TRUE", "yes", "on"}.each do |value|
      Harpy::SpecHelpers.with_env("HARPY_TRUST_PROXY", value) do
        Harpy::Config.trust_proxy?.should be_true
      end
    end
  end

  it "is false for other values" do
    {"0", "false", "no", ""}.each do |value|
      Harpy::SpecHelpers.with_env("HARPY_TRUST_PROXY", value) do
        Harpy::Config.trust_proxy?.should be_false
      end
    end
  end
end

describe "HARPY_DIFFICULTY genesis bootstrap" do
  it "mines genesis at HARPY_DIFFICULTY when creating a new chain" do
    path = File.tempname

    begin
      Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "1") do
        chain = Harpy::Storage.load_or_genesis(path)
        chain.blocks.first.difficulty.should eq(1)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "ignores HARPY_DIFFICULTY when loading an existing chain" do
    path = File.tempname
    original = Harpy::SpecHelpers.build_chain(1, difficulty: 0)

    begin
      Harpy::Storage.save(original, path)

      Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "4") do
        loaded = Harpy::Storage.load_or_genesis(path)
        loaded.blocks.first.difficulty.should eq(0)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
