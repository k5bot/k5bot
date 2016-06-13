# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class MultiMatch
      include RegexNode

      attr_reader :conditions

      def initialize(conditions)
        @conditions = conditions
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_multi_match(self)
        @conditions.first.visit(visitor, full_traverse)
        if full_traverse
          visit_rest.each do |r|
            visitor.enter_multi_match_rest(self, r)
            r.visit(visitor, full_traverse)
            visitor.leave_multi_match_rest(self, r)
          end
        end
        visitor.leave_multi_match(self)
      end

      def visit_rest
        @conditions[1..-1]
      end
    end
  end
end