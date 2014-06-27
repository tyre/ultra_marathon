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
    attr_accessor :success, :run_thread
    attr_reader :options, :name, :run_block_or_sub_context

    callbacks :before_run, :after_run, :on_error, :on_reset

    before_run lambda { logger.info "Running '#{name}' SubRunner" }
    after_run lambda { logger.info sub_context.logger.contents }
    on_reset lambda { self.run_thread = nil }

    on_error lambda { self.success = false }
    on_error lambda { |error| logger.error(error) }

    instrumentation_prefix lambda { |sub_runner| "sub_runner.#{sub_runner.name}." }

    # The :context option is required, because you'll never want to run a
    # SubRunner in context of itself.
    # SubContext is necessary because we want to run in the context of the
    # other class, but do other things (like log) in the context of this one.
    #
    #
    # @param options [Hash] the options for instantiation
    # @option options [String] :name The name of the sub runner
    # @option options [Object] :context The context in which the run block will
    #   be run. Only required if second parameter is a callable object and not
    #   a SubContext already.
    # @option options [Boolean] :instrument (false) whether to log
    #   instrumentation information.
    # @option options [Boolean] :threaded (false) whether to run in a separate
    #   thread.
    # @option options [Array, Set] :requires ([]) the names of sub runners that
    #   should have successfully run before this one. Not used by this class
    #   but necessary state for enveloping runners.
    # @param run_block_or_sub_context [Proc, SubContext] either a proc to be run
    #   within a new SubContext
    def initialize(options, run_block_or_sub_context)
      @run_block_or_sub_context = run_block_or_sub_context
      @name = options.delete(:name)
      @options = {
        instrument: false,
        threaded: false,
        requires: Set.new,
        timeout: 100
      }.merge(options)
    end

    # Run the run block or sub context. If {#threaded?} is true, will
    # envelope the run in a thread and immediately return. If there is already
    # an active thread, it will not run again.
    # @return [self]
    def run!
      if threaded?
        run_in_thread
      else
        run_without_thread
      end
      self
    end

    # Tells whether the runner has completed. If running in a threaded context,
    # checks if the thread is alive. Otherwise, returns true.
    # @return [Boolean] whether the runner has compeleted running
    def complete?
      if threaded?
        !running?
      else
        true
      end
    end

    # If {#threaded?}, returns if the run_thread is alive. Otherwise false.
    # @returns [Boolean] whether the SubRunner is currently executing {#run!}
    def running?
      if threaded?
        run_thread && run_thread.alive?
      else
        false
      end
    end

    # @return [Boolean] whether {#run!} will be executed in a thread.
    def threaded?
      !!options[:threaded]
    end

    # Invokes all on_reset callbacks
    # @return [self]
    def reset
      invoke_on_reset_callbacks
      self
    end

    # Set of all sub runners that should be run before this one, as specified
    # by the :requires option.
    # @return [Set] set of all runner names that should be run before this one.
    def parents
      @parents ||= Set.new(options[:requires])
    end

    private

    # Wraps {#run_without_thread} in a Thread unless {#running?} returns true.
    # @return [Thread, nil]
    def run_in_thread
      unless running?
        self.run_thread = Thread.new { run_without_thread }
      end
    end

    # Runs the before_run callbacks, then calls sub_context
    # If an error is raised in the sub_context, it invokes the on_error
    # callbacks passing in that error
    # Finally, runs the after_run callbacks whether or not an error was raised
    # @return [self]
    def run_without_thread
      instrument('__run!') do
        begin
          self.success = true
          instrument('callbacks.before_run') { invoke_before_run_callbacks }
          sub_context.call
        rescue StandardError => error
          instrument('callbacks.on_error') { invoke_on_error_callbacks(error) }
        ensure
          instrument('callbacks.after_run') { invoke_after_run_callbacks }
        end
      end
      log_instrumentation if options[:instrument]
      self
    end

    # Logs the start time, end time, and total time for {#run!}
    # @return [void]
    def log_instrumentation
      run_profile = instrumentations['__run!']
      logger.info """
      Start Time: #{run_profile.formatted_start_time}
      End Time: #{run_profile.formatted_end_time}
      Total Time: #{run_profile.formatted_total_time}
      """
    end

    # Returns the sub context to be called by {#run!}. If initialized with an
    # instance on SubContext, memoizes to that. Otherwise, creates a new
    # SubContext with the passed in context and run block
    # @return [SubContext]
    def sub_context
      @sub_context ||= begin
        if run_block_or_sub_context.is_a? SubContext
          run_block_or_sub_context
        else
          SubContext.new(options[:context], &run_block_or_sub_context)
        end
      end
    end
  end
end
