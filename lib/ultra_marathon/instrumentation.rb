require 'ultra_marathon/instrumentation/profile'

module UltraMarathon
  module Instrumentation
    TIME_FORMAT = "%02d:%02d:%02d"

    ## Public Instance Methods

    def instrumentations
      @instrumentations ||= Hash.new
    end

    def sorted_instrumentations
      names_and_scores = instrumentations.sort_by do |name, profile|
        profile.total_time
      end
    end

    # Returns a tuple of [name, profile] for the profile that took the longest
    def max
      sorted_instrumentations.last
    end

    # Returns a tuple of [name, profile] for the profile that took the shortest
    def min
      sorted_instrumentations.first
    end

    # Returns the mean time for profiles
    def mean_time
      @mean ||= total_times.reduce(0, :+) / instrumentations.size
    end

    # Returns a tuple of [name, profile] for the profile in the middle of the pack
    def median
      @median ||= sorted_instrumentations[instrumentations.size / 2]
    end

    # Returns the standard deviation from the mean
    # Please forgive me Mr. Brooks, I had to Google it
    def standard_deviation
      @standard_deviation ||= begin
        sum_of_deviation_squares = total_times.reduce(0) do |sum, total_time|
          sum + (mean_time - total_time) ** 2
        end
        Math.sqrt(sum_of_deviation_squares / instrumentations.size)
      end
    end

    private

    def total_times
      instrumentations.values.map(&:total_time)
    end

    ## Private Instance Methods

    # Instruments given block, setting its start time and end time
    # Returns the result of the block
    def instrument(name, &block)
      profile = Profile.new(name, &block)
      instrumentations[name] = profile
      profile.call
    end
  end
end
