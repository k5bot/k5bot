# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# noinspection RubyResolve
module ComplexRegexp
  class ComplexRegexpParser < Parslet::Parser
    def sep(regex, sep)
      regex.repeat(1, 1) >> (sep >> regex).repeat
      #self.repeat(1, 1) >> (sep >> self).repeat
    end

    rule(:esc_or_char) { str("\\") >> any | str("\\").absent? >> any }

    rule(:char_subseq) { char_class | str('[').absent? >> str(']').absent? >> esc_or_char }
    rule(:char_class, :label => 'Character Class') { str('[') >> char_subseq.repeat(1) >> str(']') }

    rule(:paren_subseq) { paren_class | str('(').absent? >> str(')').absent? >> (char_class | str('[').absent? >> str(']').absent? >> esc_or_char) }
    rule(:paren_contents) { paren_subseq.repeat(1) }
    rule(:paren_class, :label => 'Parentesized Group') { str('(') >> paren_contents >> str(')') }

    rule(:regex_text_subseq) { char_class | str('[').absent? >> str(']').absent? >> str('&').absent? >> str('(').absent? >> str(')').absent? >> esc_or_char }
    rule(:regex_text, :label => 'Regex w/o Parentheses') { regex_text_subseq.repeat(1).as(:text) }

    rule(:identifier) { match('[[:ascii:]&&[:alpha:]]') >> match('[[:ascii:]&&[:word:]]').repeat }

    rule(:paren_group_question_name, :label => 'Capture Group Name') { identifier }
    rule(:paren_group_question_quote) { str("'") >> paren_group_question_name >> str("'") }
    rule(:paren_group_question_angled) { str('<') >> paren_group_question_name >> str('>') }
    rule(:paren_groups_question, :label => 'Group w/Question Mark') {
      (
      str("'").present? >> paren_group_question_quote.as(:group_name) |
          str('<').present? >> paren_group_question_angled.as(:group_name)
      ) >> regex_with_guards.as(:group_contents) | (
      str("'").absent? >> str('<').absent? >> (
      str('#').present? >> match('[^)]').repeat(1).as(:text) |
          str('#').absent? >> regex
      ).as(:question_contents)
      )
    }
    rule(:paren_groups) {
      str('(') >> (
      str('?') >> paren_groups_question |
          str('?').absent?.as(:group_name) >> regex_with_guards.as(:group_contents)
      ) >> str(')')
    }

    rule(:regex_subseq, :label => 'Regex Sub-entity') { paren_groups | str('(').absent? >> regex_text }
    rule(:regex, :label => 'Regex') { regex_subseq.repeat(1).as(:runs) }
    rule(:regex_multimatch, :label => 'Regex Multimatch') {
      sep(regex, str('&') >> str('&').absent?).as(:conditions)
    }
    rule(:regex_multimatch?, :label => 'Regex Multimatch or Empty') {
      regex_multimatch | str('&&').present?.as(:text) | str(')').present?.as(:text) | any.absent?.as(:text)
    }

    rule(:regex_guard_name, :label => 'Regex Guard Name') { identifier }
    rule(:regex_guard_params, :label => 'Regex Guard Parameters') { str('{') >> regex_guard_name.as(:guard_name) >> str('}') | str('{').absent?.as(:guard_name) }
    rule(:regex_guard, :label => 'Regex Guard') { str('&&') >> regex_guard_params >> regex_multimatch?.as(:guard_regex) }

    rule(:regex_with_guards, :label => 'Regex w/Guards') {
      regex_multimatch?.as(:regex) >> regex_guard.repeat.as(:guards)
    }

    root :regex_with_guards
  end
end