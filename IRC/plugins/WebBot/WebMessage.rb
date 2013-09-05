# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# WebMessage describes message received via HTTP(S) request

require_relative '../../../IRC/Message'

class WebMessage
  include BotCore::Message

  attr_reader :timestamp, # reception time
              :prefix, # user in irc nick!ident@host format, for backward compatibility.
              :bot,
              :bot_command, # The first word of the message if it starts with 'command_prefix'
              :message,
              :tail # The message with nick prefix and bot_command removed if it exists, otherwise the whole message
  attr_reader :reply_array # Array of reply strings sent via this message.

  def initialize(bot, raw, prefix, session, reply_array)
    @raw = raw
    @bot = bot
    @prefix = prefix
    @session = session

    @command, @params, @user, @ctcp, @bot_command, @tail = nil
    @timestamp = Time.now
    @reply_array = reply_array
    parse(@raw)
  end

  def command
    :privmsg
  end

  def channelname
    nil
  end

=begin
  def channel
    @bot.find_channel_by_msg(self)
  end
=end

  def private?
    true
  end

  def parse(raw)
    return unless raw
    raw.strip!

    @message = raw

    m = @message && @message.match(/^\s*#{command_prefix_matcher}([\p{ASCII}\uFF01-\uFF5E&&[^\p{Z}]]+)\p{Z}*(.*)\s*/i)

    if m
      bc = m[1]
      @bot_command = bc.tr("\uFF01-\uFF5E", "\u{21}-\u{7E}").downcase.to_sym if bc
    end

    tail = (m && m[2]) || message
    @tail = tail.empty? ? nil : tail

    @bot_command ||= :j if private? && !/^[\d０１２３４５６７８９\p{Z}]+$/.match(tail)
  end

  def to_s
    @raw.to_s
  end

  # Principals of the message originator
  def principals
    @bot.user_auth.principals
  end

  # Credentials of the message originator
  def credentials
    @bot.user_auth.credentials
  end

  def user
    @bot.find_user_by_msg(self)
  end

  def ident
    return unless @prefix
    @ident ||= @prefix[/^\S+!(\S+)@/, 1]
  end

  def host
    return unless @prefix
    @host ||= @prefix[/@(\S+)$/, 1]
  end

  def nick
    return unless @prefix
    @nick ||= @prefix[/^(\S+)!/, 1]
  end

=begin
  def server
    return if @prefix =~ /[@!]/
    @server ||= @prefix
  end
=end

  def reply(text, opts = {})
    return unless can_reply?
    return unless text
    text = text.to_s
    # return if text.empty? # Allow sending empty strings in Web

    @bot.web_send(self, opts.merge(:original => text))
  end

  def can_reply?
    true
  end

  def command_prefix
    '.'
  end

  def command_prefix_matcher
    /[.．｡。]/.to_s
  end

  # Object that identifies the medium through which this message has passed.
  # This is useful to identify the group of people who may also have seen it,
  # and who will (or rather sensibly should) see our replies.
  def context
    # server, user, browser tab
    [bot.server, prefix, @session]
  end
end
