require 'set'
module UltraMarathon
  module Instrumentation
    class Store < SortedSet
      attr_reader :options

      # @param new_members [Array, Set]
      # @param options [Hash]
      # @option options [String] :prefix ('') will prefix the name of every
      #   name passed into {#instrument}
      def initialize(new_members=[], options={})
        super(new_members)
        @options = {
          prefix: ''
        }.merge(options)
      end

      # Instruments given block, setting its start time and end time
      # Stores the resulting profile in in itself
      # @param name [String] name of the instrumented block
      # @param block [Proc] block to instrument
      # @return [Object] return value of the instrumented block
      def instrument(name, &block)
        profile = Profile.new(full_name(name), &block)
        return_value = profile.call
        self.add(profile)
        return_value
      end

      # The passed in prefix
      # @return [String]
      def prefix
        options[:prefix]
      end

      # Access a profile by name. Instrumentations shouldn't have to know about
      # their fully qualified name, so the unprefixed version should be passed
      # @param name [String] name of the profile that was passed to
      #   {#instrument}
      # @return [UltraMarathon::Instrumentation::Profile, nil]
      def [](name)
        full_name = full_name(name)
        detect do |profile|
          profile.name == full_name
        end
      end

      # Accumulated total time for all stored profiles
      # @return [Float]
      def total_time
        total_times.reduce(0.0, :+)
      end

      # @return [Float] the mean time for all profiles
      def mean_runtime
        total_time / size
      end

      # @return [UltraMarthon::Instrumentation::Profile] the profile in the
      #   middle of the pack per
      #   {UltraMarthon::Instrumentation::Profile#total_time}
      def median
        to_a[size / 2]
      end


      # Please forgive me Mr. Brooks, I had to Google it
      # @return [Float] the standard deviation from the mean
      def standard_deviation
        sum_of_squares = total_times.reduce(0) do |sum, total_time|
          sum + (mean_runtime - total_time) ** 2
        end
        Math.sqrt(sum_of_squares / size)
      end

      # Adds all profiles from the other_store
      # @param other_store [UltraMarathon::Instrumentation::Profile]
      # @return [self] the other_store
      def merge!(other_store)
        other_store.each do |member|
          add(member)
        end
        self
      end

      private

      ## Private Instance Methods

      # Adds the prefix to the name
      # @param name [String] the raw name
      # @return [String] the prefixed name
      def full_name(name)
        "#{prefix}#{name}"
      end

      # @return [Array<Float>] the total times for all stored profiles
      def total_times
        map(&:total_time)
      end
    end
  end
end
