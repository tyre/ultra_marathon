require 'set'
require 'core_ext/proc'
require 'ultra_marathon/callbacks'
require 'ultra_marathon/instrumentation'
require 'ultra_marathon/logging'
require 'ultra_marathon/sub_context'

module UltraMarathon
  class SubRunner
    include Callbacks
    include Instrumentation
    include Logging
    attr_accessor :success
    attr_reader :options, :name, :run_block_or_sub_context

    callbacks :before_run, :after_run, :on_error, :on_reset

    before_run lambda { logger.info log_header }
    after_run lambda { logger.info sub_context.logger.contents }

    on_error lambda { self.success = false }
    on_error lambda { |error| logger.error(error) }

    instrumentation_prefix lambda { |sub_runner| "sub_runner.#{sub_runner.name}." }

    # The :context option is required, because you'll never want to run a
    # SubRunner in context of itself.
    # SubContext is necessary because we want to run in the context of the
    # other class, but do other things (like log) in the context of this one.
    def initialize(options, run_block_or_sub_context)
      @run_block_or_sub_context = run_block_or_sub_context
      @name = options[:name]
      @options = {
        instrument: false
      }.merge(options)
    end

    def run!
      instrument('__run!') do
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
        run_profile = instrumentations['__run!']
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

    def sub_context
      @sub_context ||= begin
        if run_block_or_sub_context.is_a? SubContext
          run_block_or_sub_context
        else
          SubContext.new(options[:context], &run_block_or_sub_context)
        end
      end
    end

    def run_sub_context
      invoke_before_run_callbacks
      sub_context.call
    end

    def log_header
      "Running '#{name}' SubRunner"
    end
  end
end
