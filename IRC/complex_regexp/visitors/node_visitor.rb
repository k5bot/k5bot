# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

module ComplexRegexp
  module Visitors
    module NodeVisitor
      def enter_node(_)
        ;
      end

      def leave_node(_)
        ;
      end

      def enter_node_rest(_, _)
        ;
      end

      def leave_node_rest(_, _)
        ;
      end

      alias_method :enter_match_any, :enter_node
      alias_method :leave_match_any, :leave_node

      alias_method :enter_simple_run, :enter_node
      alias_method :leave_simple_run, :leave_node

      alias_method :enter_complex_run, :enter_node
      alias_method :leave_complex_run, :leave_node

      alias_method :enter_multi_match, :enter_node
      alias_method :enter_multi_match_rest, :enter_node_rest
      alias_method :leave_multi_match_rest, :leave_node_rest
      alias_method :leave_multi_match, :leave_node

      alias_method :enter_guard, :enter_node
      alias_method :leave_guard, :leave_node

      alias_method :enter_guard_applicator, :enter_node
      alias_method :enter_guard_applicator_rest, :enter_node_rest
      alias_method :leave_guard_applicator_rest, :leave_node_rest
      alias_method :leave_guard_applicator, :leave_node

      alias_method :enter_capture_group, :enter_node
      alias_method :leave_capture_group, :leave_node

      alias_method :enter_question_group, :enter_node
      alias_method :leave_question_group, :leave_node
    end
  end
end