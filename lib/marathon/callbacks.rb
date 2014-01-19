require 'set'
require 'active_support/concern'
require 'active_support/core_ext/proc'

module Marathon
  module Callbacks
    extend ActiveSupport::Concern

    private

    ## Private Instance Methods

    # Check if the options' hash of conditions are met.
    # Supports :if, :unless with callable objects/symbols
    def callback_conditions_met?(options)
      conditions_met = true
      if options.key? :if
        conditions_met &&= call_proc_or_symbol(options[:if])
      elsif options.key? :unless
        conditions_met &&= !call_proc_or_symbol(options[:unless])
      end
      conditions_met
    end

    # Exectutes the object in the context of the instance,
    # whether an explicitly callable object or a string/symbol
    # representation of one
    def call_proc_or_symbol(object, args=[], options={})
      options = options.dup
      options[:context] ||= self
      bound_proc = bind_to_context(object, options[:context])
      evaluate_block_with_arguments(bound_proc, args)
    end

    # Binds a proc to the given context. If a symbol is passed in,
    # retrieves the bound method.
    def bind_to_context(symbol_or_proc, context)
      if symbol_or_proc.is_a?(Symbol)
        context.method(symbol_or_proc)
      elsif symbol_or_proc.respond_to? :call
        symbol_or_proc.bind(context)
      else
        raise ArgumentError.new("Cannot bind #{callback.class} to #{context}. Expected callable object or symbol.")
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

    module ClassMethods
      ## Public Class Methods

      # Add one or more new callbacks for class
      # E.g.
      #
      # callbacks :after_save
      #
      # Defines a class method `after_save` which
      # takes an object responding to :call (Proc or lambda)
      # or a symbol to be called in the context of the instance
      #
      # Also defines `invoke_after_save_callbacks` instance method
      # for designating when the callbacks should be invoked
      def callbacks(*callback_names)
        new_callbacks = Set.new(callback_names) - _callback_names
        new_callbacks.each do |callback_name|
          add_callbacks_accessor callback_name
          define_callback callback_name
          add_invoke_callback callback_name
        end
        self._callback_names = new_callbacks
      end

      private

      ## Private Class Methods

      # Only keep unique callback names
      def _callback_names=(new_callbacks)
        @_callback_names = _callback_names | new_callbacks
      end

      def _callback_names
        @_callback_names ||= Set.new
      end

      # On inheritance, the child should inheirit all callbacks of the
      # parent. We don't use class variables because we don't want sibling
      # classes to share callbacks
      def inherited(base)
        base.send(:callbacks, *_callback_names)
        _callback_names.each do |callback_name|
          parent_callbacks = send :"#{callback_name}_callbacks"
          base.instance_variable_set(:"@#{callback_name}_callbacks", parent_callbacks)
        end
      end

      # Defines class level accessor that memoizes the set of callbacks
      # E.g.
      #
      # def self.after_save_callbacks
      #   @after_save_callbacks ||= []
      # end
      def add_callbacks_accessor(callback_name)
        accessor_name = "#{callback_name}_callbacks"
        instance_variable_name = :"@#{accessor_name}"
        define_singleton_method("#{callback_name}_callbacks") do
          instance_variable_get(instance_variable_name) ||
          instance_variable_set(instance_variable_name, [])
        end
      end

      # Validates that the callback is valid and adds it to the callback array
      def define_callback(callback_name)
        add_callback_setter(callback_name)
        add_callback_array_writer(callback_name)
      end

      def add_callback_setter(callback_name)
        define_singleton_method(callback_name) do |callback, options={}|
          if valid_callback? callback
            send("#{callback_name}_callbacks") << [callback, options]
          else
            raise ArgumentError.new("Expected callable object or symbol, got #{callback.class}")
          end
        end
      end

      # Callbacks should either be callable (Procs, lambdas) or a symbol
      def valid_callback?(callback)
        callback.respond_to?(:call) || callback.is_a?(Symbol)
      end

      # Use protected since this is used by parent classes
      # to inherit callbacks
      def add_callback_array_writer(callback_name)
        attr_writer "#{callback_name}_callbacks"
        protected "#{callback_name}_callbacks="
      end

      # Clears all callbacks. Useful for testing and inherited classes
      def clear_callbacks!
        _callback_names.each do |callback_name|
          instance_variable_set(:"@#{callback_name}_callbacks", nil)
        end
      end

      def add_invoke_callback(callback_name)
        define_method("invoke_#{callback_name}_callbacks") do |*args|
          callbacks = self.class.send :"#{callback_name}_callbacks"
          callbacks.each do |callback, options|
            next unless callback_conditions_met?(options)
            call_proc_or_symbol(callback, args, options)
          end
        end
      end
    end
  end
end
