module Marathon
  module Instrumentation
    TIME_FORMAT = "%02d:%02d:%02d"
    attr_reader :start_time, :end_time

    ## Public Instance Methods

    # returns the total time, in seconds
    def total_time
      (end_time - start_time).to_i
    end

    def formatted_total_time
      duration = total_time
      seconds = (duration % 60).floor
      minutes = (duration / 60).floor
      hours   = (duration / 3600).floor
      sprintf(TIME_FORMAT, hours, minutes, seconds)
    end

    def formatted_start_time
      format_time(start_time)
    end

    def formatted_end_time
      format_time(end_time)
    end

    private
    def format_time(time)
      sprintf(TIME_FORMAT, time.hour, time.min, time.sec)
    end

    ## Private Instance Methods

    # Instruments given block, setting its start time and end time
    # Returns the result of the block
    def instrument(&block)
      @start_time = Time.now
      begin
        return_value = yield
      ensure
        @end_time = Time.now
      end
      return_value
    end
  end
end
