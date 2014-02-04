# UltraMarathon

Fault tolerant platform for long running jobs.

## Usage

The `UltraMarathon::AbstractRunner` class itself provides the functionality for
running complex jobs. It is best inheirited to fully customize.

### DSL

A simple DSL, currently consisting of only the `run` command, are used to
specify independent chunks of work. The first argument is the name of the run
block. Omitted, this defaults to ':main', though names must be unique within a
given Runner so for a runner with N run blocks, N - 1 must be manually named.

```ruby
class MailRunner < UltraMarathon::AbstractRunner

  # :main run block
  run do
    raise 'boom'
  end

  # :eat run block
  run :eat do
    add_butter
    add_syrup
    eat!
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

### Callbacks

`UltraMarathon::AbstractRunner` includes numerous life-cycle callbacks for
tangential code execution. Callbacks may be either callable objects
(procs/lambdas) or symbols of methods defined on the runner.

The basic flow of execution is as follows:

- `before_run`
- (`run!`)
- `after_run`
- `after_all`
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
  after_all :celebrate, :if => :success?
  after_all :cry, unless: ->{ success? }

  run do
    raise 'hell' if rand(2) % 2 == 0
  end

end
```

### Success, Failure, and Reseting

If any part of a runner fails, either by raising an error or explicitly setting
`self.success = false`, the entire run will be considered a failure. Any run blocks
which rely on an unsuccessful run block will also be considered failed.

A failed runner can be reset, which essentially changes the failed runners to
being unrun and returns the success flag to true. It will then execute any
`on_reset` callbacks before returning itself.

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
