require "./harpy/types"
require "./harpy/block"
require "./harpy/config"
require "./harpy/miner"
require "./harpy/chain"
require "./harpy/storage"
require "./harpy/server"
require "./harpy/cli"

exit Harpy::CLI.run(ARGV)
