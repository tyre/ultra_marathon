require 'set'
require 'active_support/concern'
require 'ultra_marathon/contexticution'

module UltraMarathon
  module Callbacks
    extend ActiveSupport::Concern
    include Contexticution

    private

    ## Private Instance Methods

    # Check if the options' hash of conditions are met.
    # Supports :if, :unless with callable objects/symbols
    def callback_conditions_met?(options)
      conditions_met = true
      if options.key? :if
        conditions_met &&= contexticute(options[:if])
      elsif options.key? :unless
        conditions_met &&= !contexticute(options[:unless])
      end
      conditions_met
    end

    module ClassMethods
      include Contexticution

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
          parent_callbacks = send(:"#{callback_name}_callbacks").dup
          base.instance_variable_set(:"@#{callback_name}_callbacks", parent_callbacks)
        end
      end

      # Defines class level accessor that memoizes the set of callbacks
      # @param callback_name [String, Symbol]
      # @example
      #   add_callbacks_accessor(:after_save)
      #
      #   # Equivalent to
      #   #
      #   # def self.after_save_callbacks
      #   #   @after_save_callbacks ||= []
      #   # end
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
            contexticute(callback, args, options[:context] || self)
          end
        end
      end
    end
  end
end
