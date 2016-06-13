# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class FunctionalGuard
      include RegexNode

      attr_reader :guard_name, :guard_regex
      attr_accessor :unnamed_guard_id

      def initialize(guard_name, guard_regex, unnamed_guard_id)
        @guard_name = guard_name
        @guard_regex = guard_regex
        @unnamed_guard_id = unnamed_guard_id
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_guard(self)
        guard_regex.visit(visitor, full_traverse)
        visitor.leave_guard(self)
      end
    end
  end
end