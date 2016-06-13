# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class SimpleRun
      include RegexNode

      attr_reader :text

      def initialize(text)
        @text = text
      end

      def visit(visitor, _ = false)
        visitor.enter_simple_run(self)
        visitor.leave_simple_run(self)
      end
    end
  end
end