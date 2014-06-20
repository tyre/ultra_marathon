require 'set'
require 'forwardable'

module UltraMarathon
  class Store
    include Enumerable
    extend Forwardable

    def_delegators :store, :[], :[]=, :delete, :empty?, :length, :size

    ## Public Instance Methods

    def initialize(new_runners=[])
      new_runners.each do |new_runner|
        add(new_runner)
      end
    end

    def <<(runner)
      store[runner.name] = runner
    end
    alias_method :add, :<<

    def merge(other_store)
      self.store.merge!(other_store.store)
    end

    def each(&block)
      runners.each(&block)
    end

    def pluck(&block)
      runners.map(&block)
    end

    def names
      Set.new(store.keys)
    end

    def includes_all?(query_names)
      (Set.new(query_names) - self.names).empty?
    end

    # When determining attributes, the user should always check for existence.
    # If they don't, return nil.
    def success?(name)
      if exists? name
        store[name].success
      end
    end

    def failed?(name)
      if exists? name
        !success? name
      end
    end

    def exists?(name)
      store.key? name
    end
    alias_method :exist?, :exists?

    def ==(other)
      if other.is_a? self.class
        other.names == self.names
      else
        false
      end
    end

    protected

    ## Protected Instance Methods

    # allow access for another store for merging
    def store
      @store ||= Hash.new
    end

    private

    ## Private Instance Methods

    def runners
      store.values
    end
  end
end
