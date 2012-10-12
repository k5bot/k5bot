# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Daijirin plugin

require_relative '../../IRCPlugin'
require_relative 'DaijirinEntry'
require_relative '../Menu/MenuNode'

class DaijirinMenuEntry < MenuNode
  def initialize(description, entry)
    @description = description
    @entry = entry
    @to_show = 0
  end

  def enter(from_child, msg)
    do_reply(msg, @entry)
    nil
  end

  def do_reply(msg, entry)
    if msg.private?
      # Just output everything. No need for circling logic.
      entry.info.flatten.each do |line|
          msg.reply(line)
      end

      # Print references line after everything
      format_references(entry) { |ref| msg.reply(ref) }
      return
    end

    unless @to_show
      # Restart from the first entry
      msg.reply("No more sub-entries.")
      @to_show = 0
      return
    end

    entry.info.each_with_index do |subentry, i|
      if i > @to_show
        subentry.each do |line|
          msg.notice_user(line)
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
    if @to_show >= entry.info.length
      @to_show = nil

      # Print references line together with the last entry
      format_references(entry) { |ref| msg.reply(ref) }
    else
      # Same as above, but for calling user only
      format_references(entry) { |ref| msg.notice_user(ref) }
    end
  end

  def format_references(entry)
    if entry.children
      yield entry.children.map { |c| "→ #{c.reference}" }.join(', ')
    elsif entry.parent
      yield "→#{entry.parent.reference}"
    end
  end
end
