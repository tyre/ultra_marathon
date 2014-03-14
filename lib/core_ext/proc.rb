require "active_support/core_ext/kernel/singleton_class"

#originally from active_support/core_ext/proc.rb in Rails 3.2
class Proc
  def bind(object)
    block, time = self, Time.now
    object.class_eval do
      method_name = "__bind_#{time.to_i}_#{time.usec}"
      define_method(method_name, &block)
      method = instance_method(method_name)
      remove_method(method_name)
      method
    end.bind(object)
  end
end
