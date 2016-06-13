# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'stringio'

require 'IRC/complex_regexp/visitors/node_visitor'

module ComplexRegexp
  module Visitors
    class NodeStringVisitor
      include NodeVisitor

      attr_reader :buffer

      def initialize(full_traverse = false, buffer = StringIO.new)
        @buffer = buffer
        @full_traverse = full_traverse
      end

      def enter_node(n)
        raise "Unknown Node: #{n}"
      end

      def enter_match_any(n)
        # empty string
      end

      def enter_simple_run(n)
        @buffer << n.text
      end

      def enter_complex_run(n)
        # will be filled by children
      end

      def enter_multi_match(n)
        # will be filled by children
      end

      def enter_multi_match_rest(n, child)
        @buffer << '&'
        # will be filled by children
      end

      def enter_guard(n)
        @buffer << "{#{n.guard_name}}" if @full_traverse && n.guard_name
        # will be filled by children
      end

      def enter_guard_applicator(n)
        # will be filled by children
      end

      def enter_guard_applicator_rest(n, child)
        # will be filled by children
        @buffer << '&&'
      end

      def enter_capture_group(n)
        @buffer << '('
        @buffer << "?#{n.group_name}" if n.group_name
        # will be filled by children
      end

      def leave_capture_group(n)
        @buffer << ')'
      end

      def enter_question_group(n)
        @buffer << '(?'
        # will be filled by children
      end

      def leave_question_group(n)
        @buffer << ')'
      end
    end
  end
end