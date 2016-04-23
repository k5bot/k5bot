require 'json/pure/parser'

class QuirkedJSON < JSON::Pure::Parser

  # Override parsing method to accept nothing in between array's commas.
  def parse_array
    raise NestingError, "nesting of #{@current_nesting} is too deep" if
        @max_nesting.nonzero? && @current_nesting > @max_nesting
    result = @array_class.new
    delim = false
    until eos?
      value = parse_value
      if value == UNPARSED && check(COLLECTION_DELIMITER)
        value = nil
      end
      case
        when value != UNPARSED
          delim = false
          result << value
          skip(IGNORE)
          if scan(COLLECTION_DELIMITER)
            delim = true
          elsif match?(ARRAY_CLOSE)
            ;
          else
            raise ParserError, "expected ',' or ']' in array at '#{peek(20)}'!"
          end
        when scan(ARRAY_CLOSE)
          if delim
            raise ParserError, "expected next element in array at '#{peek(20)}'!"
          end
          break
        when skip(IGNORE)
          ;
        else
          raise ParserError, "unexpected token in array at '#{peek(20)}'!"
      end
    end
    result
  end
end
