require 'active_support/concern'
require 'ultra_marathon/instrumentation/profile'
require 'ultra_marathon/instrumentation/store'

module UltraMarathon
  module Instrumentation
    extend ActiveSupport::Concern
    # Creates a default UltraMarathon::Instrumentation::Store and stores
    # all instrumented profiles there

    module ClassMethods
      ## Public Class Methods

      # @param prefix_or_proc [String, Proc] the prefix. If a Proc, it will be
      #   passed self for each instance
      # @return [String, Proc, nil]
      def instrumentation_prefix(prefix_or_proc=nil)
        if prefix_or_proc
          @instrumentation_prefix = prefix_or_proc
        else
          @instrumentation_prefix
        end
      end
    end

    # The default instrumentation store for the included class
    # @return [UltraMarathon::Instrumentation::Store]
    def instrumentations
      @instrumentations ||= UltraMarathon::Instrumentation::Store.new([], prefix: instrumentation_prefix)
    end

    private

    ## Private Instance Methods

    # @return [String] the prefix for the default instrumentation store passed
    #   to {.instrumentation_prefix}
    def instrumentation_prefix
      self.class.instrumentation_prefix.try_call(self)
    end

    # @return [Object]
    # @see UltraMarathon::Instrumentation::Store#instrument
    def instrument(*args, &block)
      instrumentations.instrument(*args, &block)
    end
  end
end
