# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Example plugin

require_relative '../../IRCPlugin'

class Example < IRCPlugin
  Description = "An example plugin."
  Commands = {
    :example => "returns an example message",
    :example_time => "returns the current time as reported by the Clock plugin",
    :example_lock => "will prevent the plugin from being unloaded",
    :example_unlock => "will make the plugin unloadable again if !example_lock has been called"
  }
  Dependencies = [ :Clock ]

  def afterLoad
    @locked = false
    @clock = @bot.pluginManager.plugins[:Clock]
  end

  def beforeUnload
    "Plugin is busy." if @locked
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :example
      msg.reply "An example message"
    when :example_time
      if @clock
        msg.reply @clock.time
      end
    when :example_lock
      msg.reply "Example plugin will now refuse unload."
      @locked = true
    when :example_unlock
      msg.reply((@locked ? "Example plugin will now accept unload." : "Example plugin hasn't been locked."))
      @locked = false
    when :example_config
      msg.reply @config.to_s
    end
  end
end
