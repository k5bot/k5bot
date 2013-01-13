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

    hier = (msg.tail || '').split.map {|x| x.downcase}

    full_ref = []
    hier.each do |keyword|
      unless sub_catalog.is_a?(Hash)
        msg.reply("#{bot_command}: can't descend further, because '#{full_ref.join(' ')}' is a string.")
        return
      end
      full_ref << keyword
      sub_catalog = sub_catalog[keyword]
      unless sub_catalog
        msg.reply("#{bot_command}: can't find key '#{full_ref.join(' ')}'.")
        return
      end
    end

    if sub_catalog.is_a?(Hash)
      msg.reply("#{([bot_command] + hier).join(' ')} contains: #{sub_catalog.keys.select {|x| !x.nil?}.join(', ')}")
    else
      msg.reply("#{([bot_command] + hier).join(' ')}: #{sub_catalog.to_s}")
    end
  end
end
