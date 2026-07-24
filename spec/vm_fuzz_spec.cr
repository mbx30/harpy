require "./spec_helper"

# VM fuzzing and property tests (MIC-63).
#
# Seeded PRNG keeps every run reproducible in CI — a failure prints the seed
# and iteration so the offending program can be replayed exactly. Mirrors the
# differential-fuzzing discipline from production-readiness research §2.2:
# the properties below must hold for *arbitrary* byte strings, not just
# well-formed programs.

private alias Vm = Harpy::Vm

FUZZ_SEED       = 0xA55E_u64 # fixed for reproducibility
FUZZ_ITERATIONS =        500

private def random_program(rng : Random, max_len : Int32 = 64) : Bytes
  len = rng.rand(0..max_len)
  Bytes.new(len) { rng.rand(0_u8..0xFF_u8) }
end

private def opcode_biased_program(rng : Random, max_len : Int32 = 64) : Bytes
  # Valid opcodes with random immediates — exercises deep paths that pure
  # random bytes rarely reach (most random bytes are InvalidOpcode).
  ops = Vm::OpCode.values
  len = rng.rand(0..max_len)
  bytes = [] of UInt8
  while bytes.size < len
    op = ops[rng.rand(ops.size)]
    bytes << op.value
    case op
    when .push1? then bytes << rng.rand(0_u8..0xFF_u8)
    when .push8? then 8.times { bytes << rng.rand(0_u8..0xFF_u8) }
    end
  end
  Bytes.new(bytes.size) { |i| bytes[i] }
end

describe "Harpy::Vm fuzzing" do
  it "never raises on arbitrary byte programs" do
    rng = Random.new(FUZZ_SEED)
    FUZZ_ITERATIONS.times do |i|
      bytecode = random_program(rng)
      begin
        Vm.run(bytecode, 10_000_u64)
      rescue ex
        fail "VM raised #{ex.class} on iteration #{i} (seed #{FUZZ_SEED}): #{bytecode.hexstring}"
      end
    end
  end

  it "never raises on opcode-biased programs" do
    rng = Random.new(FUZZ_SEED &+ 1)
    FUZZ_ITERATIONS.times do |i|
      bytecode = opcode_biased_program(rng)
      begin
        Vm.run(bytecode, 10_000_u64)
      rescue ex
        fail "VM raised #{ex.class} on iteration #{i} (seed #{FUZZ_SEED &+ 1}): #{bytecode.hexstring}"
      end
    end
  end
end

describe "Harpy::Vm properties" do
  it "is deterministic: identical inputs produce identical results" do
    rng = Random.new(FUZZ_SEED &+ 2)
    100.times do
      bytecode = opcode_biased_program(rng)
      first = Vm.run(bytecode, 5_000_u64)
      second = Vm.run(bytecode, 5_000_u64)
      second.status.should eq(first.status)
      second.gas_used.should eq(first.gas_used)
      second.stack.should eq(first.stack)
      second.storage.should eq(first.storage)
    end
  end

  it "conserves gas: gas_used + gas_remaining == gas_limit, gas_used <= limit" do
    rng = Random.new(FUZZ_SEED &+ 3)
    limit = 5_000_u64
    200.times do
      result = Vm.run(opcode_biased_program(rng), limit)
      (result.gas_used + result.gas_remaining).should eq(limit)
      result.gas_used.should be <= limit
    end
  end

  it "more gas never changes a successful outcome (gas monotonicity)" do
    rng = Random.new(FUZZ_SEED &+ 4)
    200.times do
      bytecode = opcode_biased_program(rng)
      low = Vm.run(bytecode, 2_000_u64)
      high = Vm.run(bytecode, 200_000_u64)
      if low.success?
        # A program that succeeded under the small budget must behave
        # identically under a larger one.
        high.status.should eq(low.status)
        high.stack.should eq(low.stack)
        high.storage.should eq(low.storage)
        high.gas_used.should eq(low.gas_used)
      end
    end
  end

  it "bounds the stack for every input" do
    rng = Random.new(FUZZ_SEED &+ 5)
    200.times do
      result = Vm.run(opcode_biased_program(rng, max_len: 256), 100_000_u64)
      result.stack.size.should be <= Vm::MAX_STACK_DEPTH
    end
  end

  it "leaves caller storage untouched on failure" do
    rng = Random.new(FUZZ_SEED &+ 6)
    pre = {5_u64 => 55_u64}
    200.times do
      result = Vm.run(opcode_biased_program(rng), 3_000_u64, pre)
      result.storage.should eq(pre) unless result.success?
      pre.should eq({5_u64 => 55_u64}) # input hash itself never mutated
    end
  end
end
