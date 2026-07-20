module Harpy
  # Minimal stack-based virtual machine with gas metering (MIC-64).
  #
  # Educational model of how EVM-style resource metering works: every
  # instruction burns gas, storage writes cost orders of magnitude more than
  # arithmetic, and execution always terminates — either normally (HALT / end
  # of code) or exceptionally (out of gas, stack fault, bad jump). Gas is the
  # only loop bound, so an adversarial program can never hang a node.
  #
  # Threat model and required review gates: docs/SMART_CONTRACT_THREAT_MODEL.md.
  # CI gates for this surface: docs/CONTRACT_SECURITY_CI.md.
  module Vm
    extend self

    MAX_STACK_DEPTH  = 1024
    MAX_PROGRAM_SIZE = 4096

    # Word size is UInt64 with wrapping arithmetic — overflow is defined
    # behavior (mod 2^64), never a crash or an undefined result.
    alias Word = UInt64

    enum OpCode : UInt8
      Halt     = 0x00
      Push1    = 0x01 # 1-byte immediate
      Push8    = 0x02 # 8-byte big-endian immediate
      Add      = 0x10
      Sub      = 0x11
      Mul      = 0x12
      Div      = 0x13 # x / 0 = 0 (EVM convention: total, deterministic)
      Mod      = 0x14 # x % 0 = 0
      Dup      = 0x20
      Swap     = 0x21
      Pop      = 0x22
      Jump     = 0x30 # target must be a JumpDest byte
      JumpI    = 0x31 # conditional: pops target, then condition
      JumpDest = 0x32
      Eq       = 0x50
      Lt       = 0x51
      Gt       = 0x52
      IsZero   = 0x53
      SLoad    = 0x60
      SStore   = 0x61
    end

    # Gas schedule. Storage writes are deliberately ~1000x arithmetic — the
    # scarce resource is persistent state, not CPU (mirrors EVM asymmetry).
    GAS_BASE   =    2_u64 # stack ops, comparisons, jumps
    GAS_ARITH  =    5_u64 # mul/div/mod
    GAS_SLOAD  =  200_u64
    GAS_SSTORE = 5000_u64

    def gas_cost(op : OpCode) : UInt64
      case op
      in .mul?, .div?, .mod?
        GAS_ARITH
      in .s_load?
        GAS_SLOAD
      in .s_store?
        GAS_SSTORE
      in .halt?, .push1?, .push8?, .add?, .sub?, .dup?, .swap?, .pop?,
         .jump?, .jump_i?, .jump_dest?, .eq?, .lt?, .gt?, .is_zero?
        GAS_BASE
      end
    end

    enum Status
      Success
      OutOfGas
      StackUnderflow
      StackOverflow
      InvalidOpcode
      InvalidJump
      TruncatedPush
      ProgramTooLarge
    end

    # Outcome of a single execution. `storage` reflects writes only when the
    # run succeeded — a failed execution must not mutate persistent state, so
    # callers receive the untouched pre-state on any error.
    record Result,
      status : Status,
      gas_used : UInt64,
      gas_remaining : UInt64,
      stack : Array(Word),
      storage : Hash(Word, Word) do
      def success? : Bool
        status.success?
      end
    end

    # Execute `program` with at most `gas_limit` gas against a copy of
    # `storage`. Deterministic: same program + gas + storage always produces
    # the same Result.
    def run(
      program : Bytes,
      gas_limit : UInt64,
      storage : Hash(Word, Word) = {} of Word => Word,
    ) : Result
      if program.size > MAX_PROGRAM_SIZE
        return Result.new(Status::ProgramTooLarge, 0_u64, gas_limit, [] of Word, storage)
      end

      gas = gas_limit
      stack = [] of Word
      state = storage.dup
      pc = 0

      failure = ->(status : Status, remaining : UInt64) do
        Result.new(status, gas_limit - remaining, remaining, stack, storage)
      end

      while pc < program.size
        op = OpCode.from_value?(program[pc])
        return failure.call(Status::InvalidOpcode, gas) unless op

        cost = gas_cost(op)
        return failure.call(Status::OutOfGas, 0_u64) if cost > gas
        gas -= cost
        pc += 1

        case op
        in .halt?
          break
        in .push1?
          return failure.call(Status::TruncatedPush, gas) if pc >= program.size
          return failure.call(Status::StackOverflow, gas) if stack.size >= MAX_STACK_DEPTH
          stack << program[pc].to_u64
          pc += 1
        in .push8?
          return failure.call(Status::TruncatedPush, gas) if pc + 8 > program.size
          return failure.call(Status::StackOverflow, gas) if stack.size >= MAX_STACK_DEPTH
          word = 0_u64
          8.times { |i| word = (word << 8) | program[pc + i] }
          stack << word
          pc += 8
        in .add?, .sub?, .mul?, .div?, .mod?, .eq?, .lt?, .gt?
          return failure.call(Status::StackUnderflow, gas) if stack.size < 2
          b = stack.pop
          a = stack.pop
          stack << binary_op(op, a, b)
        in .is_zero?
          return failure.call(Status::StackUnderflow, gas) if stack.empty?
          stack << (stack.pop.zero? ? 1_u64 : 0_u64)
        in .dup?
          return failure.call(Status::StackUnderflow, gas) if stack.empty?
          return failure.call(Status::StackOverflow, gas) if stack.size >= MAX_STACK_DEPTH
          stack << stack.last
        in .swap?
          return failure.call(Status::StackUnderflow, gas) if stack.size < 2
          stack[-1], stack[-2] = stack[-2], stack[-1]
        in .pop?
          return failure.call(Status::StackUnderflow, gas) if stack.empty?
          stack.pop
        in .jump?
          return failure.call(Status::StackUnderflow, gas) if stack.empty?
          target = stack.pop
          return failure.call(Status::InvalidJump, gas) unless jump_dest?(program, target)
          pc = target.to_i
        in .jump_i?
          return failure.call(Status::StackUnderflow, gas) if stack.size < 2
          target = stack.pop
          condition = stack.pop
          unless condition.zero?
            return failure.call(Status::InvalidJump, gas) unless jump_dest?(program, target)
            pc = target.to_i
          end
        in .jump_dest?
          # No-op landing pad; only these bytes are legal jump targets.
        in .s_load?
          return failure.call(Status::StackUnderflow, gas) if stack.empty?
          stack << state.fetch(stack.pop, 0_u64)
        in .s_store?
          return failure.call(Status::StackUnderflow, gas) if stack.size < 2
          key = stack.pop
          value = stack.pop
          state[key] = value
        end
      end

      Result.new(Status::Success, gas_limit - gas, gas, stack, state)
    end

    private def binary_op(op : OpCode, a : Word, b : Word) : Word
      case op
      when .add? then a &+ b
      when .sub? then a &- b
      when .mul? then a &* b
      when .div? then b.zero? ? 0_u64 : a // b
      when .mod? then b.zero? ? 0_u64 : a % b
      when .eq?  then a == b ? 1_u64 : 0_u64
      when .lt?  then a < b ? 1_u64 : 0_u64
      else            a > b ? 1_u64 : 0_u64 # .gt?
      end
    end

    private def jump_dest?(program : Bytes, target : Word) : Bool
      target < program.size && program[target.to_i] == OpCode::JumpDest.value
    end
  end
end
