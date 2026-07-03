require "digest/sha256"
require "json"

module Harpy
  struct Transaction
    include JSON::Serializable

    getter version : UInt32
    getter inputs : Array(TxInput)
    getter outputs : Array(TxOutput)

    def initialize(
      @version : UInt32 = Economics::TX_VERSION,
      @inputs : Array(TxInput) = [] of TxInput,
      @outputs : Array(TxOutput) = [] of TxOutput,
    )
    end

    def canonical_body : String
      JSON.build do |json|
        json.object do
          json.field "inputs", signing_inputs_json
          json.field "outputs", @outputs
          json.field "version", @version
        end
      end
    end

    def digest_bytes : Bytes
      Digest::SHA256.digest(canonical_body)
    end

    def txid : String
      digest_bytes.hexstring
    end

    def fee(utxo_set : UtxoSet) : UInt64
      input_sum = @inputs.sum(0_u64) do |input|
        utxo_set[input.prev_out].try(&.output.amount) || 0_u64
      end
      output_sum = @outputs.sum(0_u64, &.amount)
      return 0_u64 if input_sum < output_sum

      input_sum - output_sum
    end

    def sign_input(index : Int32, signing_key : Ed25519::SigningKey) : Transaction
      inputs = @inputs.dup
      input = inputs[index]
      sig = Crypto.sign(digest_bytes, signing_key)
      inputs[index] = TxInput.new(input.prev_out, sig, input.sig_algorithm)
      Transaction.new(@version, inputs, @outputs)
    end

    def sign_all(signing_key : Ed25519::SigningKey) : Transaction
      tx = self
      @inputs.size.times do |i|
        tx = tx.sign_input(i, signing_key)
      end
      tx
    end

    def signatures_valid?(utxo_set : UtxoSet) : Bool
      message = digest_bytes
      @inputs.all? do |input|
        entry = utxo_set[input.prev_out]
        next false unless entry
        Crypto.verify(message, input.signature, entry.output.pubkey, input.sig_algorithm)
      end
    end

    def duplicate_inputs? : Bool
      seen = Set(OutPoint).new
      @inputs.any? do |input|
        seen.includes?(input.prev_out) || !seen.add(input.prev_out)
      end
    end

    private def signing_inputs_json : Array(Hash(String, JSON::Any))
      @inputs.map(&.signing_view)
    end
  end
end
