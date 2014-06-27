module UltraMarathon
  class SubContext
    include Logging
    attr_reader :__context

    # Initializes the SubContext and defines #call as the passed in run_block
    # @param context [Object] the context in which to run the run_block. Any
    #   logging calls will be intercepted to allow threaded execution.
    # @param run_block [Proc] the block to be run in the given context
    # @return [self] the initialized SubContext
    def initialize(context, &run_block)
      @__context = context
      # Ruby cannot marshal procs or lambdas, so we need to define a method.
      # Binding to self allows us to intercept logging calls.
      define_singleton_method(:call, run_block.bind(self))
    end

    # If the original context responds, including private methods,
    # delegate to it
    #
    # @param method [Symbol] the method called. If context responds to this
    #   method, it will be called on the context
    # @param args [Array] the arguments the method was called with
    # @param block [Proc] proc called with method, if applicable
    # @raise [NoMethodError] if the context, including private methods, does not
    #   respond to the method called
    def method_missing(method, *args, &block)

      if __context.respond_to?(method, true)
        __context.send(method, *args, &block)
      else
        raise NoMethodError.new("undefined local variable or method `#{method.to_s}' for #{__context.class.name}")
      end
    end
  end
end
