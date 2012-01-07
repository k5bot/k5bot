# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCUserPool keeps track of all users. It keeps the user database
# updated by listening to user-related messages.
# To find the user who sent a message, use IRCMessage#user.

require_relative 'IRCUser'

class IRCUserPool < IRCListener
  def initialize(bot)
    super
    @users = {}
    @nicks = {}
  end

  # Finds and returns the user who send the specified message.
  # If the user is not known, a new user will be created and returned.
  # If the user is the bot itself, nil will be returned.
  # If the message is not sent by a user, nil will be returned.
  def findUser(msg)
    return unless msg.username && msg.nick
    return if msg.nick.eql?(@bot.user.nick)
    user = @users[msg.username.downcase.sub(/^~/, '')] || @nicks[msg.nick.downcase] || IRCUser.new(msg.username, msg.host, nil, msg.nick)
    @nicks.delete(user.nick.downcase) if @nicks[user.nick.downcase] == user
    user.nick = msg.nick unless msg.nick.eql?(user.nick)
    @users[user.name.downcase] = user
    @nicks[user.nick.downcase] = user
  end

  # Finds a user from nick.
  # Does not modify the user database.
  # If the user is not found, nil will be returned.
  def findUserByNick(nick)
    return if !nick || nick.empty?
    @nicks[nick.downcase]
  end

  # Finds a user from user name.
  # Does not modify the user database.
  # If the user is not found, nil will be returned.
  def findUserByUsername(username)
    return if !username || username.empty?
    @users[username.downcase]
  end

  def on_nick(msg)
    user = findUser(msg)
    return if msg.message.eql?(user.nick)
    @nicks.delete(user.nick.downcase)
    user.nick = msg.message
    @nicks[user.nick.downcase] = user
  end

  def on_privmsg(msg)
    findUser(msg)
  end
  alias on_join on_privmsg
end
