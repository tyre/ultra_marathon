require 'ultra_marathon/callbacks'
require 'ultra_marathon/instrumentation'
require 'ultra_marathon/logging'

module UltraMarathon
  class BaseRunner
    RUN_INSTRUMENTATION_NAME = :__run!
    include Logging
    include Instrumentation
    include Callbacks

    attr_accessor :success
    callbacks :before_run, :after_run, :on_error, :on_reset

    ## Public Instance Methods

    # Runs the run block safely in the context of the instance
    def run!
      if unrun_sub_runners.any?
        instrument RUN_INSTRUMENTATION_NAME do
          begin
            self.success = nil
            invoke_before_run_callbacks
            instrument(:__run_unrun_sub_runners) { run_unrun_sub_runners }
            # If any of the sub runners explicitly set the success flag, don't override it
            self.success = failed_sub_runners.empty? if self.success.nil?
          rescue StandardError => error
            invoke_on_error_callbacks(error)
          end
        end
        invoke_after_run_callbacks rescue nil
        self
      end
    end

    def success?
      !!success
    end

    # Resets success to being true, unsets the failed sub_runners to [], and
    # sets the unrun sub_runners to be the uncompleted/failed ones
    def reset
      reset_failed_runners
      @success = nil
      invoke_on_reset_callbacks
      self
    end


    # Stores sub runners which ran and were a success
    def successful_sub_runners
      @successful_sub_runners ||= Store.new
    end

    # Stores sub runners which ran and failed
    # Also store children of those which failed
    def failed_sub_runners
      @failed_sub_runners ||= Store.new
    end

    def run_instrumentation
      instrumentations[RUN_INSTRUMENTATION_NAME]
    end

    private

    ## Private Instance Methods

    # If all of the parents have been successfully run (or there are no
    # parents), runs the sub_runner.
    # If any one of the parents has failed, considers the runner a failure
    # If some parents have not yet completed, carries on
    def run_unrun_sub_runners
      unrun_sub_runners.each do |sub_runner|
        if sub_runner_can_run? sub_runner
          run_sub_runner(sub_runner)
        elsif sub_runner.parents.any? { |name| failed_sub_runners.exists? name }
          failed_sub_runners << sub_runner
          unrun_sub_runners.delete sub_runner.name
        end
      end
      run_unrun_sub_runners unless complete?
    end

    # Runs the sub runner, adding it to the appropriate sub runner store based
    # on its success or failure and removes it from the unrun_sub_runners
    def run_sub_runner(sub_runner)
      sub_runner.run!
      logger.info sub_runner.logger.contents
      if sub_runner.success
        successful_sub_runners << sub_runner
      else
        failed_sub_runners << sub_runner
      end
      unrun_sub_runners.delete sub_runner.name
    end

    ## TODO: timeout option
    def complete?
      unrun_sub_runners.empty?
    end

    # Resets all failed sub runners, then sets them as
    # @unrun_sub_runners and @failed_sub_runners to an empty Store
    def reset_failed_runners
      failed_sub_runners.each(&:reset)
      @unrun_sub_runners = failed_sub_runners
      @failed_sub_runners = Store.new
    end

    # A sub runner can run if all prerequisites have been satisfied.
    # This means all parent runners - those specified by name using the
    # :requires options - have successfully completed.
    def sub_runner_can_run?(sub_runner)
      successful_sub_runners.includes_all?(sub_runner.parents)
    end


  end
end
