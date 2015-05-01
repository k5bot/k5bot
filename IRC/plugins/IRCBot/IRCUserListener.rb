# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCUserListener keeps track of all users. It keeps the user database
# updated by listening to user-related messages.
# To find the user who sent a message, use IRCMessage#user.

require_relative '../../Listener'

require_relative 'IRCUser'

class IRCUserListener
  include BotCore::Listener

  def initialize(storage)
    @storage = storage
    @users = @nicks = nil
  end

  def on_connection(msg)
    return if @users

    @users = @storage.read('users') || {}

    @nicks = {}
    @users.values.each { |u| @nicks[normalize(u.nick)] = u }
  end

  def on_disconnection(msg)
    @nicks = nil

    @users = nil
  end

  LISTENER_PRIORITY = -40

  def listener_priority
    LISTENER_PRIORITY
  end

  def request_whois(bot, nick)
    bot.send_raw "WHOIS #{nick}"
  end

  # Finds and returns the user who send the specified message.
  # If the user is not known, a new user will be created and returned.
  # If the user is the bot itself, nil will be returned.
  # If the message is not sent by a user, nil will be returned.
  def findUser(msg)
    return unless msg.ident && msg.nick
    return if msg.nick.eql?(msg.bot.user.nick)
    user = @users[normalize(IRCUser.ident_to_name(msg.ident))] ||
        @nicks[normalize(msg.nick)] ||
        IRCUser.new(msg.ident, msg.host, nil, msg.nick)

    update_user(msg.bot.user, user, msg.nick, msg.ident, msg.host)
    user
  end

  # Finds a user from nick.
  # Does not modify the user database.
  # If the user is not found, nil will be returned.
  def findUserByNick(nick)
    return if !nick || nick.empty?
    @nicks[normalize(nick)]
  end

  # Finds a user from user name.
  # Does not modify the user database.
  # If the user is not found, nil will be returned.
  def findUserByUID(uid)
    @users[uid]
  end

  def on_nick(msg)
    user = findUser(msg)
    return unless user

    new_nick = msg.message
    return if new_nick.eql?(user.nick)

    update_user(msg.bot.user, user, new_nick)
  end

  def on_privmsg(msg)
    findUser(msg)
  end
  alias on_join on_privmsg

  #RPL_WHOISUSER
  #albel727 ~kvirc unaffiliated/albel727 * :4KVIrc 4.1.0 'Equilibrium' http://kvirc.net/
  def on_311(msg)
    nick = msg.params[1]
    user = findUserByNick(nick) || (nick.eql?(msg.bot.user.nick) ? msg.bot.user : nil)
    return unless user
    ident = msg.params[2]
    host = msg.params[3]
    realname = msg.params.last

    update_user(msg.bot.user, user, nick, ident, host, realname)
  end

  #RPL_HOSTHIDDEN:
  #K5 unaffiliated/albel727 :is now your hidden host (set by services.)
  def on_396(msg)
    host = msg.params[1]

    update_user(msg.bot.user, msg.bot.user, nil, nil, host)
  end

  private

  def maybe_update_user_map(bot_user, user, user_map, old_val, new_val)
    return false unless new_val
    return true if user == bot_user #bot mustn't end up in user maps.
    old_val = normalize(old_val)
    new_val = normalize(new_val)

    user_map.delete(old_val) if user_map[old_val] == user
    user_map[new_val] = user

    !old_val.eql?(new_val)
  end

  def update_user(bot_user, user, nick, ident=nil, host=nil, realname=nil)
    user.nick = nick if maybe_update_user_map(bot_user, user, @nicks, user.nick, nick)
    user.ident = ident if maybe_update_user_map(bot_user, user, @users, user.name, IRCUser.ident_to_name(ident))
    user.host = host if host
    user.realname = realname if realname
    store
  end

  def store
    @storage.write('users', @users)
  end

  def normalize(s)
    self.class.normalize(s)
  end

  def self.normalize(s)
    s.downcase
  end
end
