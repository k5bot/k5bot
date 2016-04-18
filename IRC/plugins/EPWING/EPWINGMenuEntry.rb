# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EPWING plugin. Menu entry for outputting next group of lines per each request.

require 'IRC/IRCPlugin'

class EPWINGMenuEntry < MenuNode
  def initialize(description, entry, book_record, preserve_gaiji)
    @description = description
    @entry = entry
    @book_record = book_record
    @preserve_gaiji = preserve_gaiji
    @to_show = 0
  end

  def enter(from_child, msg)
    do_reply(msg, @entry)
    nil
  end

  def description
    format_text(@description, @book_record.gaiji_data)
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
      msg.reply(format_text(line, @book_record.gaiji_data))
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

  def format_text(text, gaiji_data)
    text = convert_from_eb(text)
    unless @preserve_gaiji
      text = replace_gaiji(text, gaiji_data)
    end
    text
  end

  def replace_gaiji(text, gaiji_data)
    text.gsub(/<\?([WN]\h{4})\?>/) do |_|
      gaiji_data[$1.to_sym] || "<?#{$1}?>"
    end
  end

  def convert_from_eb(word)
    word.encode('UTF-8')
  end
end
