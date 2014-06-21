class Class
  def attr_memo_reader(name, memoization_block)
    define_method(name) do
      instance_variable_get(:"@#{name}") ||
      instance_variable_set(:"@#{name}", instance_exec(&memoization_block))
    end
  end

  def attr_memo_accessor(name, memoization_block)
    attr_memo_reader(name, memoization_block)
    attr_writer name
  end
end
