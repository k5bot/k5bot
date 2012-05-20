# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Git plugin

require_relative '../../IRCPlugin'

class Git < IRCPlugin
  Description = "Plugin to run git pull."
  Commands = {
    :pull => "runs git pull"
  }
  Dependencies = [ :Statistics ]

  def afterLoad
    @l = @bot.pluginManager.plugins[:Statistics]
  end

  def beforeUnload
    @l = nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :pull
      versionBefore = @l.versionString
      gitPull
      versionAfter = @l.versionString
      if versionBefore == versionAfter
        msg.reply('Already up-to-date.')
      else
        msg.reply("Updating #{versionBefore} -> #{versionAfter}")
      end
    end
  end

  def gitPull
    `pushd #{File.dirname($0)} && $(which git) fetch && $(which git) reset --hard origin/master && popd`
  end
end
