# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class CaptureGroup
      include RegexNode

      attr_reader :group_name, :group_contents
      attr_accessor :group_number

      def initialize(group_name, group_contents, group_number)
        @group_name = group_name
        @group_contents = group_contents
        @group_number = group_number
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_capture_group(self)
        group_contents.visit(visitor, full_traverse)
        visitor.leave_capture_group(self)
      end
    end
  end
end