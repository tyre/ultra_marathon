require 'core_ext/proc'

module UltraMarathon
  module Contexticution

    # @param object [Symbol, String, Proc] a symbol representing a method name,
    #   a string to be eval'd, or a proc to be called in the given context
    # @param args [Array] arguments to be passed to +object+
    # @param context [Object] the context in which to evaluate +object+. Defaults
    #   to self
    def contexticute(object, args=[], context=self)
      bound_proc = bind_to_context(object, context)
      evaluate_block_with_arguments(bound_proc, args)
    end

    private
    # Binds a proc to the given context. If a symbol is passed in,
    # retrieves the bound method. If it is a string, generates a lambda wrapping
    # it.
    def bind_to_context(object, context)
      if object.is_a?(Symbol)
        context.method(object)
      elsif object.respond_to?(:call)
        object.bind(context)
      elsif object.is_a?(String)
        eval("lambda { #{object} }").bind(context)
      else
        raise ArgumentError.new("Cannot bind #{callback.class} to #{context}. Expected Symbol, String, or object responding to #call.")
      end
    end

    # Applies a block in context with the correct number of arguments.
    # If there are more arguments than the arity, takes the first n
    # arguments where (n) is the arity of the block.
    # If there are the same number of arguments, splats them into the block.
    # Otherwise throws an argument error.
    def evaluate_block_with_arguments(block, args)
      # If block.arity < 0, when a block takes a variable number of args,
      # the one's complement (-n-1) is the number of required arguments
      required_arguments = block.arity < 0 ? ~block.arity : block.arity
      if args.length >= required_arguments
        if block.arity < 0
          instance_exec(*args, &block)
        else
          instance_exec(*args.first(block.arity), &block)
        end
      else
        raise ArgumentError.new("wrong number of arguments (#{args.size} for #{required_arguments})")
      end
    end

  end
end
