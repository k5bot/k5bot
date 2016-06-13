# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# noinspection RubyResolve
module ComplexRegexp
  class ComplexRegexTransform < Parslet::Transform
    rule(:text => simple(:text)) {
      Nodes::SimpleRun.new(text || '')
    }
    rule(:conditions => sequence(:conditions)) {
      if conditions.size == 1
        conditions.first
      else
        Nodes::MultiMatch.new(conditions)
      end
    }
    rule(:guard_name => simple(:guard_name), :guard_regex => simple(:guard_regex)) {
      Nodes::FunctionalGuard.new(guard_name.to_s.empty? ? nil : guard_name, guard_regex, nil)
    }
    rule(:regex => simple(:regex), :guards => sequence(:guards)) {
      if guards.empty?
        regex
      else
        Nodes::GuardApplicator.new(regex, guards)
      end
    }
    rule(:question_contents => simple(:question_contents)) {
      Nodes::QuestionGroup.new(question_contents)
    }
    rule(:group_name => simple(:group_name), :group_contents => simple(:group_contents)) {
      Nodes::CaptureGroup.new(group_name, group_contents, nil)
    }
    rule(:runs => sequence(:runs)) {
      r = runs.chunk(&:class).flat_map do |k, values|
        if k == Nodes::SimpleRun
          Nodes::SimpleRun.new(values.map(&:text).join)
        else
          values
        end
      end
      if r.size == 1
        r.first
      else
        Nodes::ComplexRun.new(runs)
      end
    }
  end
end