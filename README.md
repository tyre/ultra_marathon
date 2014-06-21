# UltraMarathon

Fault tolerant platform for long running jobs.

## Usage

`gem install ultra_marathon`

or with bundler:

`gem 'ultra_marathon'`

The `UltraMarathon::AbstractRunner` class itself provides the functionality for
running complex jobs. It is best inheirited to fully customize.

### DSL

A simple DSL, currently consisting of only the `run` command, are used to
specify independent chunks of work. The first argument is the name of the run
block. Omitted, this defaults to ':main', though names must be unique within a
given Runner. E.g. for a runner with N run blocks, N - 1 must be manually named.

```ruby
class MailRunner < UltraMarathon::AbstractRunner

  # :main run block
  run do
    raise 'boom'
  end

  # :eat run block
  # Must be named because there is already a :main block (one without
  # a name explicitly defined)
  run :eat do
    add_butter
    add_syrup
    eat!
  end

  # Will throw an error, since the first runner is implicitly named :main
  run :main do
    puts 'nope nope nope!'
  end

  # Omitted for brevity
  def add_butter; end
  def add_syrup; end
  def eat!; end

end

# Run the runner:
MailRunner.run!
```

Note that, while the run blocks are defined in the context of the class, they
will be run within an individual instance. Any methods should be defined as
instance methods.

In this instance, the `eat` run block will still run even if the `main` block is
executed first. Errors are caught — though they can be evaluated using the
`on_error` callback, detailed below — and the runner will attempt to complete as
many run blocks as it is able.

### Dependencies

Independent blocks are not guaranteed to run in any order, unless specifying
dependents using the `:requires` option.

```ruby
class WalrusRunner < UltraMarathon::AbstractRunner

  run :bubbles, requires: [:don_scuba_gear] do
    obtain_bubbles
  end

  run :don_scuba_gear do
    aquire_snorkel
    wear_flippers_on_flippers
  end

end
```

In this instance, `bubbles` will not be run until `don_scuba_gear` successfully
finishes. If `don_scuba_gear` explicitly fails, such as by raising an error,
`bubbles` will never be run.

### Collections

Sometimes you want to run a given run block once for each of a given set. Just
pass the `:collection` option and all of your dreams will come true. Each
iteration will be passed one item along with the index.

```ruby
class RangeRunner < UltraMarathon::AbstractRunner

  run :counting!, collection: (1..100) do |number, index|
    if index == 0
      puts "We start with #{number}"
    else
      puts "And then comes #{number}"
    end
  end

end
```

The only requirement is that the `:collection` option responds to #each. But
what if it doesn't? Just pass in the `:iterator` option! This option was added
specifically for Rails ActiveRecord::Association instances that can fetch in
batches using `:for_each`

```ruby
# Crow inherits from ActiveRecord::Base

class MurderRunner < UltraMarathon::AbstractRunner

  run :coming_of_age, collection: Crow.unblessed.where(age: 10) do |youngster_crow|
    youngster_crow.update_attribute(blessed: true)
  end

end

```

### Threading

Passing `threaded: true` will run that run block in its own thread. This is particularly useful for collections or run blocks which contain external API calls, hit a database, or any other candidate for concurrency.

```ruby
class NapRunner < UltraMarathon::AbstractRunner
  run :mass_nap, collection: (1..100), threaded: true do
    sleep(0.01)
  end
end

# nap_runner = NapRunner.new
# nap_runner.run!
```

### Callbacks

`UltraMarathon::AbstractRunner` includes numerous life-cycle callbacks for
tangential code execution. Callbacks may be either callable objects
(procs/lambdas) or symbols of methods defined on the runner.

The basic flow of execution is as follows:

- `before_run`
- (`run!`)
  - `on_error`
- `after_run`
- (`reset`)
- `on_reset`

If there is an error raised in any run block, any `on_error` callbacks will be
invoked, passing in the error if the callback takes arguments.

```ruby
class NewsRunner < UltraMarathon::AbstractRunner
  before_run :fetch_new_yorker_stories
  after_run :get_learning_on
  on_error :contemplate_existence

  run do
    NewYorker.fetch_rss_feed!
  end

  private

  def contemplate_existence(error)
    if error.is_a? HighBrowError
      puts 'Not cultured enough to understand :('
    else
      puts "Error: #{error.message}"
    end
  end

end
```

#### Options

Callbacks can, additionally, take a hash of options. Currently `:if` and
`:unless` are supported. They too can be callable objects or symbols.

```ruby
class MercurialRunner < UltraMarathon::AbstractRunner
  after_run :celebrate, :if => :success?
  after_run :cry, unless: ->{ success? }

  run do
    raise 'hell' if rand(2) % 2 == 0
  end

end
```

### Instrumentation

The entire `run!` is instrumented and logged automatically. Additionally,
individual run blocks are instrumented and logged by default.

You can also choose to not instrument a block:

```ruby
run :embarrassingly_slowly, instrument: false do
  sleep(rand(10))
end
```

### Success, Failure, and Reseting

If any part of a runner fails, either by raising an error or explicitly setting
`self.success = false`, the entire run will be considered a failure. Any run blocks
which rely on an unsuccessful run block will also be considered failed.

A failed runner can be reset, which essentially changes the failed runners to
being unrun and returns the success flag to true. Runners that have been
successfully run _will not_ be rerun, though any failed dependencies will.

The runner will then execute any `on_reset` callbacks before returning itself.

```ruby
class WatRunner < UltraMarathon::AbstractRunner
  after_reset ->{ $global_variable = 42 }
  after_run ->{ puts 'all is well in the universe'}
  run do
    unless $global_variable == 42
      puts 'wrong!'
      raise 'boom'
    end
  end

end

WatRunner.run!.reset.run!
#=> boom
#=> all is well in the universe
```
