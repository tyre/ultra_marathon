require 'set'
require 'core_ext/proc'
require 'ultra_marathon/callbacks'
require 'ultra_marathon/instrumentation'
require 'ultra_marathon/logging'

module UltraMarathon
  class SubRunner
    include Callbacks
    include Instrumentation
    include Logging
    attr_accessor :run_block, :success
    attr_reader :sub_context, :options, :name

    callbacks :before_run, :after_run, :on_error, :on_reset
    after_run :log_header_and_sub_context

    on_error lambda { self.success = false }
    on_error lambda { |error| logger.error error }

    # The :context option is required, because you'll never want to run a
    # SubRunner in context of itself.
    # SubContext is necessary because we want to run in the context of the
    # other class, but do other things (like log) in the context of this one.
    def initialize(options, run_block)
      @name = options[:name]
      @options = {
        instrument: false
      }.merge(options)
      @sub_context = SubContext.new(options[:context], run_block)
    end

    def run!
      instrument(:run) do
        begin
          self.success = true
          run_sub_context
        rescue StandardError => error
          invoke_on_error_callbacks(error)
        ensure
          invoke_after_run_callbacks
        end
      end
      log_instrumentation
    end

    def log_instrumentation
      if options[:instrument]
        run_profile = instrumentations[:run]
        logger.info """
        End Time: #{run_profile.formatted_end_time}
        Start Time: #{run_profile.formatted_start_time}
        Total Time: #{run_profile.formatted_total_time}
        """
      end
    end

    def reset
      invoke_on_reset_callbacks
    end

    # Set of all sub runners that should be run before this one.
    # This class cannot do anything with this information, but it is useful
    # to the enveloping runner.
    def parents
      @parents ||= Set.new(options[:requires])
    end

    private

    def run_sub_context
      invoke_before_run_callbacks
      sub_context.call
    end

    def log_header_and_sub_context
      logger.info log_header
      log_sub_context
    end

    def log_sub_context
      logger.info sub_context.logger.contents
    end

    def log_header
      "Running '#{name}' SubRunner"
    end
  end

  class SubContext
    include Logging
    attr_reader :context, :run_block

    def initialize(context, run_block)
      @context = context
      # Ruby cannot marshal procs or lambdas, so we need to define a method.
      # Binding to self allows us to intercept logging calls.
      define_singleton_method(:call, &run_block.bind(self))
    end

    # If the original context responds, including private methods,
    # delegate to it
    def method_missing(method, *args, &block)
      if context.respond_to?(method, true)
        context.send(method, *args, &block)
      else
        raise NoMethodError.new("undefined local variable or method `#{method.to_s}' for #{context.class.name}")
      end
    end
  end
end
