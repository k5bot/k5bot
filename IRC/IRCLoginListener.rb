# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCLoginListener is the listener that handles login-time interaction
# with an IRC server, which includes auth, setting nick, etc.

require_relative 'IRCListener'

class IRCLoginListener
  include IRCListener

  def initialize(bot)
    @bot = bot
  end

  def login
    config = @bot.config

    @bot.send "PASS #{config[:serverpass]}" if config[:serverpass]
    @bot.send "NICK #{config[:nickname]}" if config[:nickname]
    @bot.send "USER #{config[:username]} 0 * :#{config[:realname]}" if config[:username] && config[:realname]
    if config[:userpass]
      @bot.send "PRIVMSG NickServ :IDENTIFY #{config[:username]} #{config[:userpass]}"
    else
      @bot.post_login
    end
  end

  def on_notice(msg)
    config = @bot.config

    if msg.message && (msg.message =~ /^You are now identified for .*#{config[:username]}.*\.$/)
      @bot.post_login
    end
  end

  LOGIN_LISTENER_PRIORITY = -32

  def listener_priority
    LOGIN_LISTENER_PRIORITY
  end
end
