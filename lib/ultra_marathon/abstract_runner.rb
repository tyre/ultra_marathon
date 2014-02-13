require 'ultra_marathon/callbacks'
require 'ultra_marathon/instrumentation'
require 'ultra_marathon/logging'
require 'ultra_marathon/sub_runner'
require 'ultra_marathon/store'

module UltraMarathon
  class AbstractRunner
    include Logging
    include Instrumentation
    include Callbacks
    attr_accessor :success
    callbacks :before_run, :after_run, :on_error, :on_reset

    after_run :write_log
    on_error lambda { self.success = false }
    on_error lambda { |error| logger.error(error) }

    ## Public Instance Methods

    # Runs the run block safely in the context of the instance
    def run!
      if self.class.run_blocks.any?
        begin
          self.success = true
          invoke_before_run_callbacks
          instrument { run_unrun_sub_runners }
          self.success = failed_sub_runners.empty?
        rescue StandardError => error
          invoke_on_error_callbacks(error)
        ensure
          invoke_after_run_callbacks
        end
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
      @success = true
      invoke_on_reset_callbacks
      self
    end

    private

    ## Private Class Methods

    class << self

      # This is where the magic happens.
      # Called in the class context, it will be safely executed in
      # the context of the instance.
      #
      # E.g.
      #
      # class BubblesRunner < AbstractRunner
      #   run do
      #     fire_the_missiles
      #     take_a_nap
      #   end
      #
      #   def fire_the_missiles
      #     puts 'But I am le tired'
      #   end
      #
      #   def take_a_nap
      #     puts 'zzzzzz'
      #   end
      # end
      #
      #  BubblesRunner.new.run!
      #  # => 'But I am le tired'
      #  # => 'zzzzzz'
      def run(name=:main, options={}, &block)
        name = name.to_sym
        if !run_blocks.key? name
          options[:name] = name
          self.run_blocks[name] = [options, block]
        else
          raise NameError.new("Run block named #{name} already exists!")
        end
      end

      def run_blocks
        @run_blocks ||= Hash.new
      end
    end

    ## Private Instance Methods

    # Memoizes the sub runners based on the run blocks and their included
    # options.
    def unrun_sub_runners
      @unrun_sub_runners ||= begin
        self.class.run_blocks.reduce(Store.new) do |runner_store, (_name, (options, block))|
          runner_store << new_sub_runner(options, block)
          runner_store
        end
      end
    end

    # Creates a new sub runner, defaulting the context to `self`
    def new_sub_runner(options, block)
      defaults = {
        context: self
      }
      options = defaults.merge(options)
      SubRunner.new(options, block)
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

    # A sub runner can run if all prerequisites have been satisfied.
    # This means all parent runners - those specified by name using the
    # :requires options - have successfully completed.
    def sub_runner_can_run?(sub_runner)
      successful_sub_runners.includes_all?(sub_runner.parents)
    end

    # Resets all failed sub runners, then sets them as
    # @unrun_sub_runners and @failed_sub_runners to an empty Store
    def reset_failed_runners
      failed_sub_runners.each(&:reset)
      @unrun_sub_runners = failed_sub_runners
      @failed_sub_runners = Store.new
    end

    def write_log
      logger.info summary
    end

    def summary
      """

      Status: #{status}
      Start Time: #{formatted_start_time}
      End Time: #{formatted_end_time}
      Total Time: #{formatted_total_time}

      Successful SubRunners: #{successful_sub_runners.size}
      Failed SubRunners: #{failed_sub_runners.size}
      """
    end

    def status
      if success
        'Success'
      else
        'Failure'
      end
    end
  end
end
