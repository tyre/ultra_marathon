module UltraMarathon
  class SubContext
    include Logging
    attr_reader :__context

    def initialize(context, &run_block)
      @__context = context
      # Ruby cannot marshal procs or lambdas, so we need to define a method.
      # Binding to self allows us to intercept logging calls.
      define_singleton_method(:call, run_block.bind(self))
    end

    # If the original context responds, including private methods,
    # delegate to it
    def method_missing(method, *args, &block)
      if __context.respond_to?(method, true)
        __context.send(method, *args, &block)
      else
        raise NoMethodError.new("undefined local variable or method `#{method.to_s}' for #{context.class.name}")
      end
    end
  end
end
