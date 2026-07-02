require "kemal"

module Harpy::Server
  def self.start
    Harpy::Chain.genesis

    get "/" do
      Harpy::Chain.blocks.to_json
    end

    post "/new-block" do |env|
      data = env.params.json["data"].as(String)
      last_block = Harpy::Chain.tip
      new_block = Harpy::Block.generate(last_block, data)

      if Harpy::Block.valid?(new_block, last_block)
        Harpy::Chain.add(new_block)
        puts
        p new_block
        puts
      end

      new_block.to_json
    end

    Kemal.run
  end
end
