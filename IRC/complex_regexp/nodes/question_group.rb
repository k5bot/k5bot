# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/nodes/regex_node'

module ComplexRegexp
  module Nodes
    class QuestionGroup
      include RegexNode

      attr_reader :question_contents

      def initialize(question_contents)
        @question_contents = question_contents
      end

      def visit(visitor, full_traverse = false)
        visitor.enter_question_group(self)
        question_contents.visit(visitor, full_traverse)
        visitor.leave_question_group(self)
      end
    end
  end
end