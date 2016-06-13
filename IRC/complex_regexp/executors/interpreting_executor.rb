# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

module ComplexRegexp
  class InterpretingExecutor
    attr_reader :program

    def initialize(program)
      initial, *@program = program
      @initial = initial[2]
    end

    # noinspection RubyUnusedLocalVariable
    def call_guard(name, text, guard_context, regex)
      raise 'Guards are not supported by this executor'
    end

    def perform_match(initial, guard_context = nil)
      m = @initial.match(initial)
      return unless m
      results = [m]
      @program.each do |source_number, group_number, regex, match_type, param|
        source = results[source_number]
        str = group_number ? source[group_number] : source.string
        case match_type
          when :SimpleRun
            m = regex.match(str)
          when :FunctionalGuard
            m = call_guard(param, str, guard_context, regex)
          else
            raise "Unknown regex match type: #{match_type}"
        end
        return unless m
        results << m
      end
      true
    end
  end
end