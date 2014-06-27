require 'ultra_marathon/instrumentation/profile'
module UltraMarathon
  module Instrumentation
    class Profile
      DATETIME_FORMAT = '%H:%M:%S:%L'.freeze
      RAW_TIME_FORMAT = '%02d:%02d:%02d:%03d'.freeze
      attr_reader :name, :start_time, :end_time

      ## Public Instance Methods

      # @param name [String] name of the instrumented block
      # @param block [Proc] block to be instrumented
      def initialize(name, &block)
        @name = name
        # Ruby cannot marshal procs or lambdas, so we need to define a method.
        define_singleton_method :instrumented_block do
          block.call
        end
      end

      # Sets {#start_time}, runs the initialized block, then sets {#end_time}
      # @return [Object] the return value of the initialized block
      def call
        @start_time = Time.now
        begin
          return_value = instrumented_block
        ensure
          @end_time = Time.now
        end
        return_value
      end

      # @return [Float] the total time in seconds to the nanosecond
      def total_time
        @total_time ||= end_time - start_time
      end

      # @return [String] {#total_time} formatted per {RAW_TIME_FORMAT}
      def formatted_total_time
        format_seconds(total_time)
      end

      # @return [String] {#start_time} formatted per {DATETIME_FORMAT}
      def formatted_start_time
        format_time(start_time)
      end

      # @return [String] {#end_time} formatted per {DATETIME_FORMAT}
      def formatted_end_time
        format_time(end_time)
      end

      # Comparison delegated to {#total_time}
      # @param other_profile [Profile]
      # @return [Integer] {#total_time} <=> other_profile.total_time
      def <=>(other_profile)
        total_time <=> other_profile.total_time
      end

      # Profiles are considered equal if their names are `eql?`
      # @param other_profile [Profile]
      # @return [Boolean] delegates to {#name}
      def eql?(other_profile)
        name.eql? other_profile.name
      end

      private

      ## Private Instance Methods

      def format_seconds(total_seconds)
        seconds = (total_seconds % 60).floor
        minutes = (total_seconds / 60).floor
        hours   = (total_seconds / 3600).floor
        milliseconds = (total_seconds - total_seconds.to_i) * 1000.0
        sprintf(RAW_TIME_FORMAT, hours, minutes, seconds, milliseconds)
      end

      def format_time(time)
        time.strftime(DATETIME_FORMAT)
      end
    end
  end
end
