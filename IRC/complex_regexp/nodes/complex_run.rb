# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class ComplexRun
      include RegexNode

      attr_reader :runs

      def initialize(runs)
        @runs = runs
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_complex_run(self)
        runs.each do |run|
          run.visit(visitor, full_traverse)
        end
        visitor.leave_complex_run(self)
      end
    end
  end
end