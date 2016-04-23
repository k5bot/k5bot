# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require 'IRC/IRCPlugin'

class Daijirin
class DaijirinMenuEntry < MenuNode
  def initialize(description, entry)
    @description = description
    @entry = entry
    @to_show = 0
    @info = nil
  end

  def enter(from_child, msg)
    do_reply(msg, @entry)
    nil
  end

  def do_reply(msg, entry)
    # lazy non-cached info parsing
    info = parse_info(entry.raw)

    if msg.private?
      # Just output everything. No need for circling logic.
      info.flatten.each do |line|
        msg.reply(line)
      end

      # Print references line after everything
      format_references(entry) { |ref| msg.reply(ref) }
      return
    end

    unless @to_show
      # Restart from the first entry
      msg.reply('No more sub-entries.')
      @to_show = 0
      return
    end

    info.each_with_index do |subentry, i|
      if i > @to_show
        subentry.each do |line|
          msg.reply(line, :notice => true, :force_private => true)
        end
      elsif i == @to_show
        subentry.each do |line|
          msg.reply(line)
        end
      else
        # Do nothing. the entries above were printed already.
      end
    end

    @to_show += 1
    if @to_show >= info.length
      @to_show = nil

      # Print references line together with the last entry
      format_references(entry) { |ref| msg.reply(ref) }
    else
      # Same as above, but for calling user only
      format_references(entry) do |ref|
        msg.reply(ref, :notice => true, :force_private => true)
      end
    end
  end

  def format_references(entry)
    refs = entry.references
    yield(refs) if refs
  end

  def parse_info(raw)
    # Split off first line, because it might get
    # in the way of further header detection
    first_line, raw = raw.split("\n", 2)

    hierarchy = parse_rest_of_lines(raw)

    if hierarchy.instance_of?(Array)
      # There are no nested entries at all,
      # so convert it into hierarchy of one header-less text-array.
      hierarchy = {'' => hierarchy}
    end

    # Prepare to prepending the first line.
    # Ensure that initial header-less text array is existent.
    unless hierarchy['']
      hierarchy = hierarchy.to_a
      hierarchy.unshift(['', []])
      hierarchy = Hash[hierarchy]
    end

    # We actually add the first line all over again, so that
    # it will be printed with the lines of first entry.
    hierarchy[''].unshift(first_line)

    blocks = hierarchy_to_blocks(hierarchy)

    subentries = blocks_to_subentries(blocks)

    subentries.map { |lg| compact_xrefs(lg) }.to_a
  end

  # Parses the rest of lines into tree of hashes with headers as keys
  def parse_rest_of_lines(s)
    best_pos = s.length
    top_header = nil

    HEADERS.each do |header|
      pos = s =~ header
      if pos && (pos < best_pos)
        best_pos = pos
        top_header = header
      end
    end

    unless top_header
      return s.lines.map {|l| do_replacements(l.rstrip)}.to_a
    end

    key_value_array = s.split(top_header, -1).to_a

    # There is a preamble, that has no header.
    if key_value_array[0].empty?
      # If it's empty, just remove it.
      key_value_array.shift
    else
      # Otherwise, add empty header to it.
      key_value_array.unshift('')
    end

    #noinspection RubyHashKeysTypesInspection
    intermediate = Hash[*key_value_array]

    result = intermediate.map do |key, sub|
      [key, parse_rest_of_lines(sub)]
    end

    Hash[result]
  end

  # Convert entry hierarchy into blocks in the form of
  # [string of concatenated hierarchy headers, corresponding lines]
  def hierarchy_to_blocks(info)
    return [['', info]] if info.instance_of?(Array)

    result = info.each_pair.map do |key, sub|
      blocks = hierarchy_to_blocks(sub)

      blocks.each do |prefix, _|
        prefix << key
      end

      first_block_lines = blocks[0][1]
      first_block_lines[0] = key + first_block_lines[0]

      blocks
    end

    result.flatten(1)
  end

  # Groups prefixed blocks together
  # into subentries (text that is output together).
  # Everything from the beginning down to and including
  # the first entry in the lowest-level list
  # will be in the same subentry,
  # thanks to key postfix checking.
  def blocks_to_subentries(blocks)
    prev_key = ''
    result = []

    accumulator = []
    blocks.each do |key, lines|
      unless key.end_with?(prev_key)
        result << accumulator
        accumulator = []
      end
      accumulator += lines
      prev_key = key
    end

    result << accumulator unless accumulator.empty?

    result
  end

  def compact_xrefs(lines_group)
    replacement = nil

    lines_group.map do |line|
      if line.match(/^\s*[→⇔]/)
        if replacement
          replacement << ', '
          replacement << line
          nil
        else
          replacement = line.dup
          replacement
        end
      else
        replacement = nil
        line
      end
    end.delete_if do |line|
      line.nil?
    end
  end

  HEADERS = [
      /^(□[一二三四五六七八九十]+□)/,
      /^(■[一二三四五六七八九十]+■)/,
      /^(（[\d１２３４５６７８９０]+）)/,
      /^([❶❷❸❹❺❻❼❽❾❿⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴])/,
  ]

  REPLACEMENTS = {
      '（ア）' => '㋐',
      '（イ）' => '㋑',
      '（ウ）' => '㋒',
      '（エ）' => '㋓',
      '（オ）' => '㋔',
  }

  REPLACEMENTS_REGEX = Regexp.new(REPLACEMENTS.keys.map {|key| Regexp.escape(key)}.join('|'))

  def do_replacements(s)
    s.gsub(REPLACEMENTS_REGEX) do |match|
      REPLACEMENTS[match]
    end
  end
end
end