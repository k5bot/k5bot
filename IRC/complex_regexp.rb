# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'parslet'
require 'parslet/convenience'

IRCPlugin.remove_required 'IRC/complex_regexp/nodes'
IRCPlugin.remove_required 'IRC/complex_regexp/visitors'
IRCPlugin.remove_required 'IRC/complex_regexp/executors'

require 'IRC/complex_regexp/nodes/simple_run'
require 'IRC/complex_regexp/nodes/complex_run'
require 'IRC/complex_regexp/nodes/multi_match'
require 'IRC/complex_regexp/nodes/functional_guard'
require 'IRC/complex_regexp/nodes/guard_applicator'
require 'IRC/complex_regexp/nodes/capture_group'
require 'IRC/complex_regexp/nodes/question_group'

require 'IRC/complex_regexp/visitors/node_string_visitor'
require 'IRC/complex_regexp/visitors/node_numbering_visitor'
require 'IRC/complex_regexp/visitors/node_group_checker_visitor'
require 'IRC/complex_regexp/visitors/node_complexity_visitor'

require 'IRC/complex_regexp/complex_regexp_parser'
require 'IRC/complex_regexp/complex_regex_transform'

require 'IRC/complex_regexp/executors/interpreting_executor'

module ComplexRegexp
  def self.strip_complex_whitespace(regex)
    regex.gsub(/(?<!\\)&\s+/, '&').gsub(/\s+&/, '&')
  end

  def self.parse(s)
    # HACK: Parslet spams with uninitialized variable warnings
    vrb = $VERBOSE
    # noinspection RubyGlobalVariableNamingConvention
    $VERBOSE = false
    begin
      res = ComplexRegexp::ComplexRegexpParser.new.parse(s, reporter: Parslet::ErrorReporter::Contextual.new)
      ComplexRegexp::ComplexRegexTransform.new.apply(res)
    rescue Parslet::ParseFailed => error
      #raise ComplexRegexp::get_error_oneliner(error)
      raise error
    ensure
      # noinspection RubyGlobalVariableNamingConvention
      $VERBOSE = vrb
    end
  end

  def self.program(root)
    plan = []
    queue = [[nil, nil, root]]
    while queue.size > 0
      source_number, group_number, node = queue.shift

      reg_str = Visitors::NodeStringVisitor.new.tap do |visitor|
        node.visit(visitor)
      end.buffer.string

      regex = Regexp.new(reg_str)

      node.visit(Visitors::NodeNumberingVisitor.new(!regex.names.empty?))
      node.visit(Visitors::NodeGroupCheckerVisitor)

      src_num = plan.size

      Visitors::NodeComplexityVisitor.new.tap do |visitor|
        node.visit(visitor)
        visitor.complexity.each do |gn, n|
          n.visit_rest.each do |rest|
            queue << [src_num, gn, rest]
          end
        end
      end

      param = if node.is_a?(Nodes::FunctionalGuard)
                (node.guard_name ? node.guard_name : node.unnamed_guard_id).to_s
              end

      plan << [
          source_number,
          group_number,
          regex,
          node.class.name.split('::').last.to_sym,
          param,
      ]
    end

    plan[0][3..4] = [:SimpleRun, nil]

    bad_matches = plan.find_all do |_, _, _, match_type|
      match_type != :SimpleRun && match_type != :FunctionalGuard
    end.map {|a| a[3]}.uniq

    unless bad_matches.empty?
      raise "Bug. Invalid regexp plan. Unexpected match type(s): #{bad_matches.join(', ')}"
    end

    plan
  end

  def self.get_plan_types(plan)
    types = []
    plan.each do |source_number, _, _, match_type, param|
      source_type = source_number ? types[source_number] : []
      case match_type
        when :SimpleRun
          types << source_type.dup
        when :FunctionalGuard
          types << (source_type.dup << param)
        else
          raise "Bug! Unknown regex match type: #{match_type}"
      end
    end
    types
  end

  def self.get_plan_group_depths(plan)
    types = []
    plan.each do |source_number, group_number, _, _, _|
      source_type = source_number ? types[source_number] : 0
      types << source_type + (group_number ? 1 : 0)
    end
    types
  end

  def self.get_error_oneliner(error)
    err_traverse(error.cause).to_a.reverse.max_by(&:last).first.to_s
  end

  def self.guard_names_to_symbols(plan, supported_guards)
    bad_guards = []
    plan = plan.map do |s, g, r, match_type, param|
      next [s, g, r, match_type, param] unless match_type == :FunctionalGuard
      replacement = supported_guards[param.downcase]
      bad_guards << param unless replacement
      [s, g, r, match_type, replacement]
    end

    unless bad_guards.empty?
      raise "Unknown guard name(s): #{bad_guards.join(', ')}"
    end
    plan
  end

  def self.check_types_nesting(types)
    type_errors = types.find_all do |type|
      yield(type)
    end.uniq

    unless type_errors.empty?
      type_errors = type_errors.map do |type|
        type.reverse.join(' in ')
      end.join(', ')
      raise "Incorrectly nested guard(s): #{type_errors}"
    end
  end

  # This function splits plan in two by cutting out nodes
  # together with their ancestors, for which given block yields true.
  def self.plan_split(plan)
    idx = -1
    indices = []
    cut, remainder = plan.partition do |a|
      idx += 1
      if indices.include?(a[0]) || yield(*a)
        indices << idx
        true
      end
    end

    cut.map! do |a|
      a = a.dup
      a[0] = indices.index(a[0])
      a
    end

    remainder.map! do |a|
      a = a.dup
      orig_idx = a[0]
      next a unless orig_idx
      a[0] -= indices.find_all {|deleted_idx| deleted_idx < orig_idx }.size
      a
    end

    [cut, remainder]
  end

  # Context free fetcher here is a guard that doesn't depend on call position
  # in regex, as it doesn't actually use parent string,
  # and instead just performs simple regex match on some other string it
  # fetches from somewhere else.
  # Multiple calls to such guard can be replaced with multimatch, reusing
  # match.source from the call to the first of them.
  # This replacement is what this function does, for given guard names.
  def self.replace_context_free_fetchers(plan, fetcher_guard_names)
    donor_indices = fetcher_guard_names.map do |fetcher_guard_name|
      donor_idx = plan.index do |_, _, _, match_type, param|
        match_type == :FunctionalGuard && param == fetcher_guard_name
      end
      [fetcher_guard_name, donor_idx]
    end.to_h

    idx = -1
    plan.map do |s, g, r, match_type, param|
      idx += 1
      next [s, g, r, match_type, param] unless match_type == :FunctionalGuard && donor_indices[param] && donor_indices[param] < idx
      [donor_indices[param], nil, r, :SimpleRun, nil]
    end
  end

  private

  def self.err_traverse(error, depth = 0)
    return enum_for(__method__, error, depth) unless block_given?

    yield(error, depth)
    error.children.each do |c|
      err_traverse(c, depth+1) do |*args|
        yield(*args)
      end
    end
  end
end