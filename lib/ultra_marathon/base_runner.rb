require 'ultra_marathon/callbacks'
require 'ultra_marathon/instrumentation'
require 'ultra_marathon/logging'

module UltraMarathon
  class BaseRunner
    RUN_INSTRUMENTATION_NAME = '__run!'.freeze
    include Logging
    include Instrumentation
    include Callbacks

    attr_accessor :success
    attr_memo_accessor :threaded_runners, -> { [] }
    attr_memo_reader :successful_sub_runners, -> { Store.new }
    attr_memo_reader :failed_sub_runners, -> { Store.new }

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
        invoke_after_run_callbacks
      end
      self
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
      until complete?
        unrun_sub_runners.each do |sub_runner|
          if sub_runner_can_run? sub_runner
            run_sub_runner sub_runner
          elsif sub_runner.parents.any? { |name| failed_sub_runners.exists? name }
            failed_sub_runners << sub_runner
            unrun_sub_runners.delete sub_runner.name
          end
        end
        clean_up_threaded_runners if threaded_runners.any?
      end
    end

    # Either explicitly runs the sub runner or, if it is threaded, starts its
    # thread
    def run_sub_runner(sub_runner)
      if sub_runner.threaded?
        self.threaded_runners << sub_runner.run_thread
      else
        sub_runner.run!
        clean_up_sub_runner(sub_runner)
      end
    end

    # Adds a run sub runner to the appropriate sub runner store based
    # on its success or failure and removes it from the unrun_sub_runners
    # Also merges its instrumentation to the group's instrumentation
    def clean_up_sub_runner(sub_runner)
      if sub_runner.success
        successful_sub_runners << sub_runner
      else
        failed_sub_runners << sub_runner
      end
      instrumentations.merge!(sub_runner.instrumentations)
      unrun_sub_runners.delete sub_runner.name
    end

    # Cleans up all dead threads, settings
    def clean_up_threaded_runners
      alive_threads, dead_threads = threaded_runners.partition(&:alive?)
      dead_threads.each do |thread|
        clean_up_sub_runner(thread.value)
      end
      self.threaded_runners = alive_threads
    end

    ## TODO: timeout option
    def complete?
      self.threaded_runners.empty? && unrun_sub_runners.empty?
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

    def status
      if success?
        'Success'
      else
        'Failure'
      end
    end

    def log_all_sub_runners
      log_failed_sub_runners if failed_sub_runners.any?
      log_successful_sub_runners if successful_sub_runners.any?
    end

    def log_failed_sub_runners
      logger.info """

      == Failed SubRunners ==

      """
      log_sub_runners(failed_sub_runners)
    end

    def log_successful_sub_runners
      logger.info """

      == Successful SubRunners ==

      """
      log_sub_runners(successful_sub_runners)
    end


    def log_sub_runners(sub_runners)
      sub_runners.each do |sub_runner|
        logger.info(sub_runner.logger.contents << "\n")
      end
    end

    def log_summary
      run_profile = instrumentations[:run!]
      failed_names = failed_sub_runners.names.map(&:to_s).join(', ')
      succcessful_names = successful_sub_runners.names.map(&:to_s).join(', ')
      unrun_names = unrun_sub_runners.names.map(&:to_s).join(', ')
      logger.info """

      Status: #{status}

      Failed (#{failed_sub_runners.size}): #{failed_names}
      Successful (#{successful_sub_runners.size}): #{succcessful_names}
      Unrun (#{unrun_sub_runners.size}): #{unrun_names}

      #{time_summary}

      """
    end

    def sub_runner_instrumentations
      @sub_runner_instrumentations ||= begin
        sub_runner_profiles = instrumentations.select do |profile|
          profile.name.to_s.start_with? 'sub_runner.'
        end
        UltraMarathon::Instrumentation::Store.new(sub_runner_profiles)
      end
    end

    def time_summary
      """
      Run Start Time: #{run_instrumentation.formatted_start_time}
      End Time: #{run_instrumentation.formatted_end_time}
      Total Time: #{run_instrumentation.formatted_total_time}

      #{sub_runner_summary if sub_runner_instrumentations.any?}
      """
    end

    def sub_runner_summary
      median_profile = sub_runner_instrumentations.median
      max_profile = sub_runner_instrumentations.max
      min_profile = sub_runner_instrumentations.min
      """
      Max SubRunner Runtime: #{max_profile.name} (#{max_profile.total_time})
      Min SubRunner Runtime: #{min_profile.name} (#{min_profile.total_time})
      Median SubRunner Runtime: #{median_profile.name} (#{median_profile.total_time})
      SubRunner Runtime Standard Deviation: #{sub_runner_instrumentations.standard_deviation}
      """
    end
  end
end
