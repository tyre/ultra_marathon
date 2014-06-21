require 'set'
require 'ultra_marathon/base_runner'
require 'ultra_marathon/store'
require 'ultra_marathon/sub_context'
require 'ultra_marathon/sub_runner'

module UltraMarathon
  class CollectionRunner < BaseRunner
    attr_reader :collection, :options, :run_block

    after_run :write_logs
    instrumentation_prefix lambda { |collection| "collection.#{collection.name}." }

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
        sub_runner: SubRunner,
        iterator:   :each
      }.merge(options)
    end

    def unrun_sub_runners
      @unrun_sub_runners ||= begin
        store = Store.new
        index = 0
        collection.send(options[:iterator]) do |item|
          this_index = index
          index += 1
          store << new_item_sub_runner(item, this_index)
        end
        store
      end
    end

    # Set of all sub runners that should be run before this one.
    # This class cannot do anything with this information, but it is useful
    # to the enveloping runner.
    def parents
      @parents ||= Set.new(options[:requires])
    end

    private

    def write_logs
      log_header
      log_all_sub_runners
      log_summary
    end

    def log_header
      logger.info "Running Collection #{options[:name]}"
    end

    # Cache the sub runner class
    def sub_runner_class
      @individual_runner_class ||= options[:sub_runner].try_call
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
      sub_runner_base_options.merge(name: options[:sub_name].try_call(index, item))
    end

    def build_item_sub_context(item, options)
      SubContext.new(options[:context]) do
        instance_exec(*item, &run_block)
      end
    end
  end
end
