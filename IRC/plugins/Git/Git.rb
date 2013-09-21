# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Git plugin

require_relative '../../IRCPlugin'

class Git < IRCPlugin
  Description = "Plugin to run git pull."
  Commands = {
    :pull => "fetches changes from upstream and resets current branch and working directory to reflect it",
    :upstream => "shows from where changes are pulled"
  }
  Dependencies = [ :Statistics ]

  def afterLoad
    @l = @plugin_manager.plugins[:Statistics]
  end

  def beforeUnload
    @l = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :pull
      versionBefore = @l.versionString
      gitPull
      versionAfter = @l.versionString
      if versionBefore == versionAfter
        msg.reply('Already up-to-date.')
      else
        msg.reply("Updating #{versionBefore} -> #{versionAfter}")
      end
    when :upstream
      msg.reply(gitUpstream)
    end
  end

  def gitPull
    `pushd #{File.dirname($0)} && $(which git) fetch && $(which git) reset --hard @{upstream} && popd`
  end

  def gitUpstream
    upstream = `pushd #{File.dirname($0)} >/dev/null 2>&1 && $(which git) branch -vv | grep -e '^\*' && popd >/dev/null 2>&1`[/\[([^\[]+)\]/, 1]
    remote = upstream[/([^\/]+)\/([^:]+).*/, 1]
    branch = upstream[/([^\/]+)\/([^:]+).*/, 2]
    remoteURL = `pushd #{File.dirname($0)} >/dev/null 2>&1 && $(which git) remote -v | grep #{remote} | head -1 && popd >/dev/null 2>&1`.split[1]
    "upstream is [#{branch}] at #{remoteURL}"
  end
end
