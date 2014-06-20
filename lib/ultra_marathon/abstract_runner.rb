require 'ultra_marathon/base_runner'
require 'ultra_marathon/sub_runner'
require 'ultra_marathon/store'

module UltraMarathon
  class AbstractRunner < BaseRunner

    after_run :write_log
    on_error lambda { self.success = false }
    on_error lambda { |error| logger.error(error) }

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

    def write_log
      logger.info summary
    end

    def summary
      """

      Status: #{status}
      Run Start Time: #{run_instrumentation.formatted_start_time}
      End Time: #{run_instrumentation.formatted_end_time}
      Total Time: #{run_instrumentation.formatted_total_time}

      Successful SubRunners: #{successful_sub_runners.size}
      Failed SubRunners: #{failed_sub_runners.size}
      """
    end

    def status
      if success?
        'Success'
      else
        'Failure'
      end
    end
  end
end
