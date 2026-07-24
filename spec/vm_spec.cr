require "./spec_helper"

private alias Vm = Harpy::Vm
private alias Op = Harpy::Vm::OpCode

private def program(*parts : Int32 | Array(Int32)) : Bytes
  ops = [] of Int32
  parts.each { |part| part.is_a?(Array) ? ops.concat(part) : (ops << part) }
  Bytes.new(ops.size) { |i| ops[i].to_u8 }
end

private def push1(value : Int32) : Array(Int32)
  [Op::Push1.value.to_i, value]
end

describe Harpy::Vm do
  describe "arithmetic" do
    it "adds two values" do
      result = Vm.run(program(push1(2), push1(3), Op::Add.value.to_i), 100_u64)
      result.success?.should be_true
      result.stack.should eq([5_u64])
    end

    it "wraps on overflow instead of raising" do
      max = Bytes[Op::Push8.value, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        Op::Push1.value, 1, Op::Add.value]
      result = Vm.run(max, 100_u64)
      result.success?.should be_true
      result.stack.should eq([0_u64])
    end

    it "defines division by zero as zero" do
      result = Vm.run(program(push1(7), push1(0), Op::Div.value.to_i), 100_u64)
      result.success?.should be_true
      result.stack.should eq([0_u64])
    end

    it "computes sub, mul, mod" do
      result = Vm.run(program(push1(10), push1(3), Op::Mod.value.to_i), 100_u64)
      result.stack.should eq([1_u64])
      result = Vm.run(program(push1(10), push1(3), Op::Sub.value.to_i), 100_u64)
      result.stack.should eq([7_u64])
      result = Vm.run(program(push1(10), push1(3), Op::Mul.value.to_i), 100_u64)
      result.stack.should eq([30_u64])
    end
  end

  describe "comparisons" do
    it "evaluates eq, lt, gt, iszero" do
      Vm.run(program(push1(4), push1(4), Op::Eq.value.to_i), 100_u64).stack.should eq([1_u64])
      Vm.run(program(push1(3), push1(4), Op::Lt.value.to_i), 100_u64).stack.should eq([1_u64])
      Vm.run(program(push1(3), push1(4), Op::Gt.value.to_i), 100_u64).stack.should eq([0_u64])
      Vm.run(program(push1(0), Op::IsZero.value.to_i), 100_u64).stack.should eq([1_u64])
    end
  end

  describe "stack operations" do
    it "dup, swap, pop behave" do
      result = Vm.run(program(push1(1), push1(2), Op::Dup.value.to_i), 100_u64)
      result.stack.should eq([1_u64, 2_u64, 2_u64])
      result = Vm.run(program(push1(1), push1(2), Op::Swap.value.to_i), 100_u64)
      result.stack.should eq([2_u64, 1_u64])
      result = Vm.run(program(push1(1), push1(2), Op::Pop.value.to_i), 100_u64)
      result.stack.should eq([1_u64])
    end

    it "underflows deterministically" do
      Vm.run(program(Op::Add.value.to_i), 100_u64).status.should eq(Vm::Status::StackUnderflow)
      Vm.run(program(Op::Pop.value.to_i), 100_u64).status.should eq(Vm::Status::StackUnderflow)
    end

    it "enforces max stack depth" do
      # PUSH1 0 repeated beyond MAX_STACK_DEPTH must overflow, not OOM.
      ops = [] of Int32
      (Vm::MAX_STACK_DEPTH + 1).times { ops.concat(push1(0)) }
      result = Vm.run(program(ops), 10_000_u64)
      result.status.should eq(Vm::Status::StackOverflow)
    end
  end

  describe "control flow" do
    it "jumps only to JumpDest" do
      # Layout: 0:PUSH1 1:target 2:JUMP 3:HALT 4:JUMPDEST 5:PUSH1 6:9 7:HALT
      bytecode = program(Op::Push1.value.to_i, 4, Op::Jump.value.to_i, Op::Halt.value.to_i,
        Op::JumpDest.value.to_i, Op::Push1.value.to_i, 9, Op::Halt.value.to_i)
      result = Vm.run(bytecode, 100_u64)
      result.success?.should be_true
      result.stack.should eq([9_u64])
    end

    it "rejects jumps into immediates or arbitrary bytes" do
      bytecode = program(Op::Push1.value.to_i, 3, Op::Jump.value.to_i, Op::Halt.value.to_i)
      Vm.run(bytecode, 100_u64).status.should eq(Vm::Status::InvalidJump)
    end

    it "takes conditional jump only when condition is nonzero" do
      # cond, target on stack; layout: 0:PUSH1 1:cond 2:PUSH1 3:6 4:JUMPI 5:HALT 6:JUMPDEST 7:PUSH1 8:7
      taken = program(Op::Push1.value.to_i, 1, Op::Push1.value.to_i, 6, Op::JumpI.value.to_i,
        Op::Halt.value.to_i, Op::JumpDest.value.to_i, Op::Push1.value.to_i, 7)
      Vm.run(taken, 100_u64).stack.should eq([7_u64])

      skipped = program(Op::Push1.value.to_i, 0, Op::Push1.value.to_i, 6, Op::JumpI.value.to_i,
        Op::Halt.value.to_i, Op::JumpDest.value.to_i, Op::Push1.value.to_i, 7)
      Vm.run(skipped, 100_u64).stack.should be_empty
    end

    it "terminates an infinite loop by gas exhaustion" do
      # 0:JUMPDEST 1:PUSH1 2:0 3:JUMP — loops forever without a gas limit.
      loop_program = program(Op::JumpDest.value.to_i, Op::Push1.value.to_i, 0, Op::Jump.value.to_i)
      result = Vm.run(loop_program, 1_000_u64)
      result.status.should eq(Vm::Status::OutOfGas)
      result.gas_remaining.should eq(0_u64)
    end
  end

  describe "storage and gas metering" do
    it "stores and loads through persistent state" do
      # value=42 key=7 SSTORE; key=7 SLOAD
      bytecode = program(push1(42), push1(7), Op::SStore.value.to_i,
        push1(7), Op::SLoad.value.to_i)
      result = Vm.run(bytecode, 10_000_u64)
      result.success?.should be_true
      result.stack.should eq([42_u64])
      result.storage[7_u64].should eq(42_u64)
    end

    it "reads absent keys as zero" do
      result = Vm.run(program(push1(9), Op::SLoad.value.to_i), 1_000_u64)
      result.stack.should eq([0_u64])
    end

    it "charges storage writes orders of magnitude above arithmetic" do
      (Vm::GAS_SSTORE // Vm::GAS_ARITH).should be >= 1000
      write = program(push1(1), push1(1), Op::SStore.value.to_i)
      exact = Vm::GAS_BASE * 2 + Vm::GAS_SSTORE
      Vm.run(write, exact).success?.should be_true
      Vm.run(write, exact - 1).status.should eq(Vm::Status::OutOfGas)
    end

    it "does not persist storage from failed executions" do
      pre = {1_u64 => 10_u64}
      # Successful SSTORE then an underflow: state must revert to pre-state.
      bytecode = program(push1(99), push1(1), Op::SStore.value.to_i, Op::Add.value.to_i)
      result = Vm.run(bytecode, 10_000_u64, pre)
      result.status.should eq(Vm::Status::StackUnderflow)
      result.storage.should eq(pre)
    end

    it "accounts gas_used + gas_remaining = gas_limit" do
      result = Vm.run(program(push1(2), push1(3), Op::Mul.value.to_i), 100_u64)
      (result.gas_used + result.gas_remaining).should eq(100_u64)
      result.gas_used.should eq(Vm::GAS_BASE * 2 + Vm::GAS_ARITH)
    end
  end

  describe "malformed programs" do
    it "rejects unknown opcodes" do
      Vm.run(Bytes[0xEE], 100_u64).status.should eq(Vm::Status::InvalidOpcode)
    end

    it "rejects truncated push immediates" do
      Vm.run(Bytes[Op::Push1.value], 100_u64).status.should eq(Vm::Status::TruncatedPush)
      Vm.run(Bytes[Op::Push8.value, 1, 2, 3], 100_u64).status.should eq(Vm::Status::TruncatedPush)
    end

    it "rejects programs over the size cap" do
      big = Bytes.new(Vm::MAX_PROGRAM_SIZE + 1, Op::Halt.value)
      Vm.run(big, 100_u64).status.should eq(Vm::Status::ProgramTooLarge)
    end

    it "accepts the empty program" do
      result = Vm.run(Bytes.empty, 100_u64)
      result.success?.should be_true
      result.gas_used.should eq(0_u64)
    end
  end
end
