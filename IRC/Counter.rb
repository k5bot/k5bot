# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Counting set helper class

class Counter
  def initialize
    @counter = Hash.new(0)
  end

  def add(obj)
    val = @counter[obj]
    @counter[obj] = val + 1
    yield obj if block_given? && val == 0
  end

  def remove(obj)
    val = @counter[obj]
    return if 0 >= val
    if val > 1
      @counter[obj] = val - 1
    else
      @counter.delete(obj)
      yield obj if block_given?
    end
  end
end
