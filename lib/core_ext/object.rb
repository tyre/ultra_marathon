class Object
  # Many times an option can either be a callable object (Proc/Lambda) or
  # not (symbol/string/integer). This will call with the included arguments,
  # if it is callable, or return the object if not.
  def try_call(*args)
    if respond_to? :call
      call(*args)
    else
      self
    end
  end
end
