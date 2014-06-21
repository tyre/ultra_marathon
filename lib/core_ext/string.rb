class String

  # Included for the kids.
  def sploin(seperator, joiner, &block)
    ary = split(seperator)
    ary.map!(&block) if block_given?
    ary.join(joiner)
  end
end
