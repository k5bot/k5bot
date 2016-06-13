# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/visitors/node_visitor'

module ComplexRegexp
  module Visitors
    class NodeComplexityVisitor
      include NodeVisitor

      attr_reader :complexity

      def initialize
        @group_stack = [nil]
        @complexity = []
      end

      def enter_multi_match(n)
        @complexity << [@group_stack.last, n]
      end

      def enter_guard_applicator(n)
        @complexity << [@group_stack.last, n]
      end

      def enter_capture_group(n)
        @group_stack << n.group_number
      end

      def leave_capture_group(n)
        @group_stack.pop
      end
    end
  end
end