# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Git plugin

require 'IRC/IRCPlugin'

class Git
  include IRCPlugin
  DESCRIPTION = 'Plugin to run git pull.'
  COMMANDS = {
    :pull => 'fetches changes from upstream and resets current branch and working directory to reflect it',
    :upstream => 'shows from where changes are pulled',
  }
  DEPENDENCIES = [:Statistics]

  def afterLoad
    @statistics = @plugin_manager.plugins[:Statistics]
  end

  def beforeUnload
    @statistics = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :pull
      version_before = @statistics.version_string
      git_pull
      version_after = @statistics.version_string
      if version_before == version_after
        msg.reply('Already up-to-date.')
      else
        msg.reply("Updating #{version_before} -> #{version_after}")
      end
    when :upstream
      msg.reply(git_upstream)
    end
  end

  def git_pull
    `pushd #{File.dirname($0)} && $(which git) fetch && $(which git) reset --hard @{upstream} && popd`
  end

  def git_upstream
    upstream = `pushd #{File.dirname($0)} >/dev/null 2>&1 && $(which git) branch -vv | grep -e '^\*' && popd >/dev/null 2>&1`[/\[([^\[]+)\]/, 1]
    remote = upstream[/([^\/]+)\/([^:]+).*/, 1]
    branch = upstream[/([^\/]+)\/([^:]+).*/, 2]
    remote_url = `pushd #{File.dirname($0)} >/dev/null 2>&1 && $(which git) remote -v | grep #{remote} | head -1 && popd >/dev/null 2>&1`.split[1]
    "upstream is [#{branch}] at #{remote_url}"
  end
end
