require 'set'
module UltraMarathon
  module Instrumentation
    class Store < SortedSet
      attr_reader :options

      def initialize(new_members=[], options={})
        super(new_members)
        @options = {
          prefix: ''
        }.merge(options)
      end

      # Instruments given block, setting its start time and end time
      # Stores the resulting profile in in itself
      #
      # IMPORTANT: All keys will be converted to strings. You've been warned
      def instrument(name, &block)
        profile = Profile.new(full_name(name), &block)
        return_value = profile.call
        self.add(profile)
        return_value
      end

      def prefix
        options[:prefix] || ''
      end

      def [](name)
        full_name = full_name(name)
        detect do |profile|
          profile.name == full_name
        end
      end

      # Accumulated total time for all stored profiles
      def total_time
        total_times.reduce(0, :+)
      end

      # Returns the mean time for profiles
      def mean_runtime
        total_time / size
      end

      # Returns the profile in the middle of the pack
      # TIL sets don't let you take one out an an index
      def median
        to_a[size / 2]
      end

      # Returns the standard deviation from the mean
      # Please forgive me Mr. Brooks, I had to Google it
      def standard_deviation
        sum_of_squares = total_times.reduce(0) do |sum, total_time|
          sum + (mean_runtime - total_time) ** 2
        end
        Math.sqrt(sum_of_squares / size)
      end

      def merge!(other_store)
        other_store.each do |member|
          add(member)
        end
      end

      private

      ## Private Instance Methods

      # Adds the prefix to the name
      def full_name(name)
        "#{prefix}#{name}"
      end

      def total_times
        map(&:total_time)
      end
    end
  end
end
