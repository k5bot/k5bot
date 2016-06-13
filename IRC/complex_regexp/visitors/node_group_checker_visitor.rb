# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/visitors/node_visitor'

module ComplexRegexp
  module Visitors
    module NodeGroupCheckerVisitor
      extend NodeVisitor

      def enter_guard_applicator(n)
        # will be filled by children
      end

      def enter_capture_group(n)
        if !n.group_number && (n.capture.is_a?(MultiMatch) || n.capture.is_a?(GuardApplicator))
          raise "Can't use multimatch/guard features in non-capturing groups"
        end
      end
    end
  end
end