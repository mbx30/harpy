module Harpy
  module Difficulty
    extend self

    def required_for_block(ancestor_blocks : Array(Block)) : Int32
      retarget(ancestor_blocks)
    end

    def retarget(blocks : Array(Block), interval : Int32 = Economics::RETARGET_INTERVAL) : Int32
      return blocks.last?.try(&.difficulty) || Block::DEFAULT_DIFFICULTY if blocks.size < 2

      if blocks.size % interval != 0
        return blocks.last.difficulty
      end

      window_start = [blocks.size - interval, 0].max
      start_block = blocks[window_start]
      end_block = blocks.last

      actual_seconds = time_delta_seconds(start_block.timestamp, end_block.timestamp)
      actual_seconds = 1_i64 if actual_seconds < 1

      target_seconds = interval.to_i64 * Economics::TARGET_BLOCK_TIME_SEC
      current = end_block.difficulty

      adjusted = (current.to_f64 * target_seconds.to_f64 / actual_seconds.to_f64).round.to_i32
      adjusted = Economics::MIN_DIFFICULTY if adjusted < Economics::MIN_DIFFICULTY
      adjusted = Economics::MAX_DIFFICULTY if adjusted > Economics::MAX_DIFFICULTY
      adjusted
    end

    private def time_delta_seconds(start_ts : String, end_ts : String) : Int64
      start_time = Time.parse(start_ts, "%Y-%m-%d %H:%M:%S UTC", Time::Location::UTC)
      end_time = Time.parse(end_ts, "%Y-%m-%d %H:%M:%S UTC", Time::Location::UTC)
      (end_time - start_time).total_seconds.to_i64
    rescue Time::Format::Error
      1_i64
    end
  end
end
