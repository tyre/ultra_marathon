module UltraMarathon
  module Instrumentation
    class Profile
      attr_reader :name, :instrument_block, :start_time, :end_time

      ## Public Instance Methods

      def initialize(name, &block)
        @name = name
        # Ruby cannot marshal procs or lambdas, so we need to define a method.
        # Binding to self allows us to intercept logging calls.
        define_singleton_method :instrumentated_block do
          block.call
        end
      end

      def call
        @start_time = Time.now
        begin
          return_value = instrumentated_block
        ensure
          @end_time = Time.now
        end
        return_value
      end

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

      ## Private Instance Methods

      def format_time(time)
        sprintf(TIME_FORMAT, time.hour, time.min, time.sec)
      end
    end
  end
end
