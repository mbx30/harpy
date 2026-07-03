require "./spec_helper"

describe "chain property and fork-choice integration" do
  it "invalidates the chain when any block field is randomly tampered" do
    rng = Random.new(37)

    24.times do
      chain = Harpy::SpecHelpers.build_chain(3 + rng.rand(3))
      block_index = rng.rand(chain.height)
      field = Harpy::SpecHelpers::TAMPER_FIELDS.sample(rng)
      tampered_blocks = chain.blocks.dup
      tampered_blocks[block_index] = Harpy::SpecHelpers.tamper_block(tampered_blocks[block_index], field)

      Harpy::Chain.new(tampered_blocks).valid?.should be_false
    end
  end

  it "rejects forks with equal cumulative work" do
    main = Harpy::SpecHelpers.build_chain(3)
    genesis = main.blocks.first
    equal_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 3, "equal-work")

    main.cumulative_work.should eq(equal_fork.cumulative_work)
    main.replace_if_more_work_valid!(equal_fork.blocks).should be_false
    main.height.should eq(3)
  end

  it "rejects a longer fork with lower cumulative work" do
    main = Harpy::SpecHelpers.build_chain(3, difficulty: 2)
    genesis = main.blocks.first
    longer_low_work = Harpy::SpecHelpers.extend_fork_from(genesis, 6, "longer-low-work", difficulty: 0)

    longer_low_work.height.should be > main.height
    longer_low_work.cumulative_work.should be < main.cumulative_work
    main.replace_if_more_work_valid!(longer_low_work.blocks).should be_false
    main.height.should eq(3)
  end

  it "accepts a shorter fork with higher cumulative work" do
    main = Harpy::SpecHelpers.build_chain(5, difficulty: 0)
    genesis = main.blocks.first
    shorter_high_work = Harpy::SpecHelpers.extend_fork_from(genesis, 2, "shorter-high-work", difficulty: 2)

    shorter_high_work.height.should be < main.height
    shorter_high_work.cumulative_work.should be > main.cumulative_work
    main.replace_if_more_work_valid!(shorter_high_work.blocks).should be_true
    main.valid?.should be_true
    main.height.should eq(2)
  end

  it "accepts a longer valid competing chain with more cumulative work" do
    main = Harpy::SpecHelpers.build_chain(2)
    genesis = main.blocks.first
    longer_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "longer")

    main.replace_if_more_work_valid!(longer_fork.blocks).should be_true
    main.valid?.should be_true
    main.height.should eq(4)
  end

  it "rejects an invalid candidate even when it has more cumulative work" do
    main = Harpy::SpecHelpers.build_chain(2)
    genesis = main.blocks.first
    longer_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "longer")
    broken_blocks = longer_fork.blocks.dup
    broken_blocks[2] = Harpy::SpecHelpers.tamper_block(broken_blocks[2], "hash")

    main.replace_if_more_work_valid!(broken_blocks).should be_false
    main.height.should eq(2)
  end
end

describe "stored chain boot validation" do
  it "refuses to boot when a mid-chain block hash was tampered on disk" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(3)

    begin
      Harpy::Storage.save(chain, path)
      blocks = chain.blocks.dup
      blocks[1] = Harpy::Block.new(
        blocks[1].index,
        blocks[1].timestamp,
        blocks[1].transactions,
        blocks[1].prev_hash,
        blocks[1].difficulty,
        blocks[1].nonce,
        "deadbeef",
        blocks[1].merkle_root,
      )
      File.write(path, Harpy::Storage::Envelope.wrap(blocks).to_json)

      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
