module Harpy
  module Difficulty
    extend self

    TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S UTC"

    def required_for_block(ancestor_blocks : Array(Block)) : Int32
      retarget(ancestor_blocks)
    end

    def retarget(blocks : Array(Block), interval : Int32 = Economics::RETARGET_INTERVAL) : Int32
      retarget_values(blocks.map(&.difficulty), blocks.map(&.timestamp), interval)
    end

    def retarget_headers(headers : Array(BlockHeader), interval : Int32 = Economics::RETARGET_INTERVAL) : Int32
      retarget_values(headers.map(&.difficulty), headers.map(&.timestamp), interval)
    end

    def valid_timestamp?(candidate : String, blocks : Array(Block), now : Time = Time.utc) : Bool
      timestamp_valid_for_values?(candidate, blocks.map(&.timestamp), now)
    end

    def valid_header_timestamp?(candidate : String, headers : Array(BlockHeader), now : Time = Time.utc) : Bool
      timestamp_valid_for_values?(candidate, headers.map(&.timestamp), now)
    end

    def valid_genesis_timestamp?(timestamp : String, now : Time = Time.utc) : Bool
      parsed = parse_timestamp(timestamp)
      !!parsed && parsed <= now + Economics::MAX_FUTURE_DRIFT_SEC.seconds
    end

    def valid_difficulty?(difficulty : Int32) : Bool
      difficulty >= Economics::MIN_DIFFICULTY && difficulty <= Economics::MAX_DIFFICULTY
    end

    def next_timestamp(blocks : Array(Block), now : Time = Time.utc) : String
      window = blocks.last(Economics::MEDIAN_TIME_WINDOW)
      times = window.compact_map { |block| parse_timestamp(block.timestamp) }.sort
      candidate = now
      unless times.empty?
        minimum = times[times.size // 2] + 1.second
        candidate = minimum if candidate < minimum
      end
      candidate.to_s(TIMESTAMP_FORMAT)
    end

    def parse_timestamp(value : String) : Time?
      Time.parse(value, TIMESTAMP_FORMAT, Time::Location::UTC)
    rescue Time::Format::Error
      nil
    end

    private def retarget_values(difficulties : Array(Int32), timestamps : Array(String), interval : Int32) : Int32
      current = difficulties.last? || Block::DEFAULT_DIFFICULTY
      return current if difficulties.size < 2

      return current if difficulties.size % interval != 0

      window_start = [timestamps.size - interval, 0].max
      start_time = parse_timestamp(timestamps[window_start])
      end_time = parse_timestamp(timestamps.last)
      return current unless start_time && end_time

      actual_seconds = (end_time - start_time).total_seconds.to_i64
      target_intervals = Math.max(interval - 1, 1)
      target_seconds = target_intervals.to_i64 * Economics::TARGET_BLOCK_TIME_SEC

      adjusted = if actual_seconds < target_seconds // 2
                   current + 1
                 elsif actual_seconds > target_seconds * 2
                   current - 1
                 else
                   current
                 end

      adjusted = Economics::MIN_DIFFICULTY if adjusted < Economics::MIN_DIFFICULTY
      adjusted = Economics::MAX_DIFFICULTY if adjusted > Economics::MAX_DIFFICULTY
      adjusted
    end

    private def timestamp_valid_for_values?(candidate : String, ancestor_timestamps : Array(String), now : Time) : Bool
      parsed = parse_timestamp(candidate)
      return false unless parsed
      return false if parsed > now + Economics::MAX_FUTURE_DRIFT_SEC.seconds
      return true if ancestor_timestamps.empty?

      window = ancestor_timestamps.last(Economics::MEDIAN_TIME_WINDOW)
      times = window.compact_map { |timestamp| parse_timestamp(timestamp) }.sort
      return false unless times.size == window.size

      parsed > times[times.size // 2]
    end
  end
end
