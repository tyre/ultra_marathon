require 'ultra_marathon/store'
require 'ultra_marathon/logging'
require 'ultra_marathon/sub_context'
module UltraMarathon
  class CollectionRunner
    include Logging
    attr_reader :collection, :options, :run_block

    # Takes a collection, each of which will be run in its own subrunner. The collection
    # Also takes a number of options:
    #
    # name:       The name of the collection run block
    # sub_name:   A callable object (passed the index of the collection) that
    #             should return a unique (to the collection) name for that subrunner
    #             Defaults to :"#{options[:name]}__#{index}"
    # sub_runner: Class inheiriting from UltraMarathon::SubRunner in which each
    #             run_block will be run
    #             Defaults to UltraMarathon::SubRunner
    #
    # iterator:   Method called to iterate over collection. For example, a Rails
    #             application may wish to use :find_each with an ActiveRecord::Relation
    #             to batch queries
    #             Defaults to :each
    #
    def initialize(collection, options={}, &run_block)
      @collection, @run_block = collection, run_block
      @options = {
        sub_name: proc { |index| :"#{options[:name]}__#{index}" },
        sub_runner: UltraMarathon::SubRunner,
        iterator:   :each
      }.merge(options)
      initialize_sub_runners
    end

    # Cache the sub runner class
    def sub_runner_class
      @individual_runner_class ||= options[:sub_runner].try_call
    end

    def run!
      sub_runners.each(&:run!)
      combined_logs = sub_runners.map { |sub_runner| sub_runner.logger.contents }.join("\n")
      logger.info(combined_logs)
      self
    end

    def initialize_sub_runners
      index = 0
      collection.send(options[:iterator]) do |item|
        this_index = index
        index += 1
        sub_runners << new_item_sub_runner(item, this_index)
      end
    end

    def new_item_sub_runner(item, index)
      item_options = sub_runner_item_options(item, index)
      item_sub_context = build_item_sub_context(item, item_options)
      sub_runner_class.new(item_options, item_sub_context)
    end

    # By default, run the sub runner inside this context. Unlikely to be what you
    # want
    def sub_runner_base_options
      {
        context: options[:context] || self
      }
    end

    def sub_runner_item_options(item, index)
      sub_runner_base_options.merge(name: options[:sub_name].try_call(index))
    end

    def sub_runners
      @sub_runners ||= Store.new
    end

    def build_item_sub_context(item, options)
      SubContext.new(options[:context]) do
        instance_exec(*item, &run_block)
      end
    end
  end
end
