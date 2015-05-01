# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# LayoutableText is an interface for logically presenting
# a long text as lines fitting some constraints, monotonic in
# string length (i.e. if some line satisfies the constraint,
# then the constraint must be satisfied by any line of smaller length).

module LayoutableText
  # This method must return an array of strings, satisfying
  # the constraint passed as a block. Various keyword arguments
  # can be used by specific subclasses. But caller mustn't
  # assume that all subclasses understand any specific option.
  # Passed constraints must understand variable keyword arguments
  # for future compatibility. Presently, the only fixed argument
  # expected of a constraint block is the line to check.
  #
  # Constraint argument minimum_size is true, if layouted line
  # can't be made any smaller, it's useful for constraints that
  # want to accept the smallest line at a last resort,
  # even if otherwise it wouldn't have satisfied the constraint.
  def layout_calculate(**opts) raise 'ni!' end

  # This must be overridden for the sake of those
  # who didn't know or care about our class and just
  # expected to receive a string to print.
  # def to_s(*args) ; raise 'Must be implemented!' end


  # Simple layouter that just outputs the single string it contains
  class SingleString
    include LayoutableText

    def initialize(str)
      @str = str
    end

    def layout_calculate(max_lines: 1, **)
      raise "Can't fit in #{max_lines} lines" unless max_lines > 0
      line = yield(@str, minimum_size: true, check_only: false)
      raise "Line doesn't fit constraint: #{@str}" unless line
      [line]
    end

    def to_s
      @str
    end
  end

  # A layouter that attempts to cut given array into chunks,
  # each of which fits in a line that satisfies given constraint.
  # The protected method format_chunk can be overridden by subclasses
  # to provide more complicated chunk formatting.
  # This implementation can actually accept a string instead of an array,
  # with the string being split into several substrings as a result.
  # max_lines parameter can be specified, in which case at most this much
  # lines will be laid out, and what remains is silently omitted.
  class Arrayed
    include LayoutableText

    def initialize(arr, max_lines = nil)
      @arr = arr
      @max_lines = max_lines
    end

    def layout_calculate(max_lines: @max_lines, **)
      input_array = @arr.dup
      output_array = []
      until input_array.empty? || (max_lines && max_lines <= 0)
        max_lines -= 1 if max_lines

        chunk_size = (0...input_array.size).bsearch do |cs|
          cs = input_array.size - cs # invert search range

          is_last_line = (max_lines && max_lines <= 0) || (cs == input_array.size)
          formatted_line = format_chunk(input_array, cs, is_last_line)
          !!yield(formatted_line, minimum_size: cs <= 1, check_only: true)
        end

        raise "Can't lay out array: #{input_array}" unless chunk_size

        chunk_size = input_array.size - chunk_size # invert search range

        is_last_line = (max_lines && max_lines <= 0) || (chunk_size == input_array.size)
        formatted_line = format_chunk(input_array, chunk_size, is_last_line)
        output_line = yield(formatted_line, minimum_size: chunk_size <= 1, check_only: false)
        output_array << output_line

        input_array.slice!(0, chunk_size)
      end
      output_array
    end

    def to_s
      format_chunk(@arr, @arr.size, true)
    end

    protected

    def format_chunk(arr, chunk_size, _)
      arr.slice(0, chunk_size).to_s
    end
  end

  # Simple subclass of Arrayed, that performs a join
  # with given separator string on every chunk.
  class SimpleJoined < Arrayed
    def initialize(separator, *args)
      super(*args)
      @separator = separator
    end

    protected

    def format_chunk(arr, chunk_size, _)
      arr.slice(0, chunk_size).join(@separator)
    end
  end

  # A class for stacked layout modification. Every line is altered
  # by a protected method delegated_format() prior to constraint checking.
  class Delegated
    include LayoutableText

    def initialize(layoutable)
      @layoutable = layoutable
    end

    def layout_calculate(**opts)
      @layoutable.layout_calculate(**opts) do |line, **constraint_opts|
        yield(delegated_format(line), **constraint_opts)
      end
    end

    def to_s
      delegated_format(@layoutable.to_s)
    end

    protected

    def delegated_format(line)
      line
    end
  end

  # Simple subclass of Delegated layouter, that
  # prefixes each line with a given prefix.
  class Prefixed < Delegated
    def initialize(prefix, *args)
      super(*args)
      @prefix = prefix
    end

    protected

    def delegated_format(line)
      "#{@prefix}#{line}"
    end
  end
end
