require 'support/file_mutexes'

module TestHelpers

  # create an anonymous test class so we don't pollute the global namespace
  def anonymous_test_class(inherited_class=Object, &block)
    Class.new(inherited_class).tap do |klass|
      klass.class_eval(&block) if block_given?
    end
  end
end
