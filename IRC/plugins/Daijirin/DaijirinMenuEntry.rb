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
  end

  def enter(from_child, msg)
    do_reply(msg, @entry)
    nil
  end

  def do_reply(msg, entry)
    show_publicly = true
    entry.to_lines.each_with_index do |line, i|
      if show_publicly
        msg.reply(line)
      else
        msg.notice_user(line)
      end
      show_publicly = false if line.match(/^\s*（(?:１|1)）/) or i > 2
    end
  end
end
