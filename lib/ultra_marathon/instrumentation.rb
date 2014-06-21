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

      def instrumentation_prefix(prefix_or_proc=nil)
        if prefix_or_proc
          @instrumentation_prefix = prefix_or_proc
        else
          @instrumentation_prefix
        end
      end
    end

    def instrumentations
      @instrumentations ||= UltraMarathon::Instrumentation::Store.new([], prefix: instrumentation_prefix)
    end

    private

    def instrumentation_prefix
      prefix_or_proc = self.class.instrumentation_prefix
      if prefix_or_proc.respond_to? :call
        prefix_or_proc.call(self)
      else
        prefix_or_proc
      end
    end

    ## Private Instance Methods

    def instrument(*args, &block)
      instrumentations.instrument(*args, &block)
    end
  end
end
