# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'IRC/complex_regexp/visitors/node_visitor'

module ComplexRegexp
  module Visitors
    class NodeNumberingVisitor
      include NodeVisitor

      def initialize(named_mode)
        @counter = 0
        @named_mode = named_mode
      end

      def enter_guard_applicator(n)
        idx = 1
        n.guards.each do |g|
          unless g.guard_name
            g.unnamed_guard_id = idx
            idx += 1
          end
        end
      end

      def enter_capture_group(n)
        return unless n.group_name && @named_mode || !n.group_name && !@named_mode
        @counter += 1
        n.group_number = @counter
      end
    end
  end
end