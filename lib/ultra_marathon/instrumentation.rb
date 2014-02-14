require 'ultra_marathon/instrumentation/profile'

module UltraMarathon
  module Instrumentation
    TIME_FORMAT = "%02d:%02d:%02d"

    ## Public Instance Methods

    def instrumentations
      @instrumentations ||= Hash.new
    end

    private

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
