# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# MapDoc plugin presents 'mapdoc' YAML file with hash in it as browsable dictionary

require_relative '../../IRCPlugin'

class MapDoc < IRCPlugin
  Description = "Provides access to simple associative array of text."

  Dependencies = [ :StorageYAML ]

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @catalog = @storage.read('mapdoc') || {}
  end

  def commands
    Hash[@catalog.map do |command, sub_catalog|
      [command, sub_catalog[nil]] # nil keys are used as descriptions
    end]
  end

  def beforeUnload
    @catalog = nil

    @storage = nil

    nil
  end

  def on_privmsg(msg)
    if msg.botcommand
      respond_to_query(msg)
    end
  end

  def respond_to_query(msg)
    bot_command = msg.botcommand

    return unless @catalog
    sub_catalog = @catalog[bot_command]
    return unless sub_catalog

    hier = (msg.tail || '').split

    full_ref = []
    case_ambiguous = []

    hier.each do |keyword|
      unless sub_catalog.is_a?(Hash)
        msg.reply("#{bot_command}: can't descend further, because '#{full_ref.join(' ')}' is a string.")
        return
      end

      # Find all keys that case-insensitively match with given keyword
      case_ambiguous = sub_catalog.keys.find_all { |w| w && (0 == keyword.casecmp(w)) }
      case case_ambiguous.size
        when 0
          # Found nothing.
          word = nil
        when 1
          # Only one variant. Assume user meant that.
          word = case_ambiguous.pop
        else
          # Several variants. See if one of them matches case-sensitively with keywords.
          # If yes, then use it, the rest is to be shown as suggestions.
          # Otherwise everything will be shown as suggestions.
          word = case_ambiguous.delete(keyword)
      end

      # If not found anything, just use keyword for help printing purposes.
      word ||= keyword

      sub_catalog = sub_catalog[word]
      unless sub_catalog
        reply = "#{bot_command}: can't find key '#{word}'"
        reply += " in '#{full_ref.join(' ')}'" unless full_ref.empty?
        reply += '.'
        reply += " Maybe you meant: #{case_ambiguous.join(', ')}." unless case_ambiguous.empty?
        msg.reply(reply)
        return
      end

      full_ref << word
    end

    if sub_catalog.is_a?(Hash)
      print_catalog_keys([bot_command] + full_ref, sub_catalog, msg)
      reply = format_see_also(case_ambiguous, full_ref)
    else
      reply = "#{([bot_command] + full_ref).join(' ')}: #{sub_catalog.to_s}"
      see_also = format_see_also(case_ambiguous, full_ref)
      reply += ' ' + see_also if see_also
    end

    msg.reply(reply)
  end

  def print_catalog_keys(full_ref, sub_catalog, msg)
    all_keys = sub_catalog.keys.select { |x| !x.nil? }

    until all_keys.empty?
      chunk_size = all_keys.size

      begin
        text = "#{full_ref.join(' ')} contains: #{all_keys[0..chunk_size-1].join(', ')}"
        # make msg.reply throw exception if the text doesn't fit
        msg.reply(text, :dont_truncate => (chunk_size > 1))
      rescue Exception => _
        # sending without truncation failed
        chunk_size-=1
        # retry with smaller menu size
        retry if chunk_size > 0
      end

      all_keys.slice!(0, chunk_size)
    end
  end

  def format_see_also(case_ambiguous, full_ref)
    return if case_ambiguous.empty?
    reply = "See also: #{case_ambiguous.join(', ')}"
    full_ref.pop # drop last matched key
    reply += " in '#{full_ref.join(' ')}'" unless full_ref.empty?
    reply += '.'

    reply
  end
end
