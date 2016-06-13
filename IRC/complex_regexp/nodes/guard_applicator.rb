# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class GuardApplicator
      include RegexNode

      attr_reader :regex, :guards

      def initialize(regex, guards)
        @regex = regex
        @guards = guards
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_guard_applicator(self)
        regex.visit(visitor, full_traverse)
        if full_traverse
          visit_rest.each do |r|
            visitor.enter_guard_applicator_rest(self, r)
            r.visit(visitor, full_traverse)
            visitor.leave_guard_applicator_rest(self, r)
          end
        end
        visitor.leave_guard_applicator(self)
      end

      def visit_rest
        guards
      end
    end
  end
end