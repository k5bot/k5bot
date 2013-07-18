# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EPWING plugin. Menu entry for outputting next group of lines per each request.

require_relative '../../IRCPlugin'
require_relative '../Menu/MenuNode'

class EPWINGMenuEntry < MenuNode
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
    unless @to_show
      # Restart from the first subentry
      msg.reply('No more pieces.')
      @to_show = 0
      return
    end

    unless @to_show < entry.size
      raise 'Bug! Empty text entry given.'
    end

    entry[@to_show].each do |line|
      msg.reply(line)
    end

    @to_show += 1
    if @to_show >= entry.size
      @to_show = nil
    else
      remaining = entry.size - @to_show
      msg.reply("[#{remaining} #{pluralize('piece', remaining)} left. Choose same entry to view...]")
    end
  end

  def pluralize(str, num)
    num != 1 ? str + 's' : str
  end
end
