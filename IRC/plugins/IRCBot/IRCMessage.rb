# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCMessage describes a message
#
# [:<prefix>] <command> [<param> <param> ... :<param>]
#
# <prefix> does not contain spaces and specified from where the message comes.
# <prefix> is always prefixed with ':'.
# <command> may be either a three-digit number or a string of at least one letter.
# There may be at most 15 <param>s.
# A <param> is always one word, except the last <param> which can be multiple words if prefixed with ':',
# unless it is the 15th <param> in which case ':' is optional.

class IRCMessage
  attr_reader :prefix, :command, :params, :timestamp, :bot

  def initialize(bot, raw)
    @prefix, @command, @params, @user, @ctcp = nil
    @timestamp = Time.now
    @bot = bot
    parse @raw = raw
  end

  def parse(raw)
    return unless raw
    raw.strip!
    msg_parts = raw.to_s.split(/[ 　]/)
    @prefix = msg_parts.shift[1..-1] if msg_parts.first.start_with? ':'
    @command = msg_parts.shift.downcase.to_sym
    @params = []
    @params << msg_parts.shift while msg_parts.first and !msg_parts.first.start_with? ':'
    msg_parts.first.slice!(0) if msg_parts.first
    @params.delete_if{|param| param.empty?}
    @params << msg_parts.join(' ') if !msg_parts.empty?
  end

  def to_s
    @raw.dup
  end

  def user
    @user ||= @bot.find_user_by_msg(self)
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

  def server
    return if @prefix =~ /[@!]/
    @server ||= @prefix
  end

  # The first word of the message if it starts with !
  def botcommand
    return unless @command == :privmsg
    bc = message ? message[/^\s*(#{@bot.user.nick}\s*[:>,]?\s*)?#{Regexp.quote(command_prefix)}([\S]+)/i, 2] : nil
    bc.downcase.to_sym if bc
  end

  # The channel name (e.g. '#channel')
  def channelname
    @params[-2] if @params[-2] && @params[-2][/^#/]
  end

  def channel
    @bot.find_channel_by_msg(self)
  end

  # The last parameter
  def message
    @params.last if @params
  end

  # The message with nick prefix and botcommand removed if it exists, otherwise the whole message
  def tail
    tail = message ? message[/^\s*(#{@bot.user.nick}\s*[:>,]?\s*)?#{Regexp.quote(command_prefix)}([\S]+)\s*(.*)\s*/i, 3] || message : nil
    tail.empty? ? nil : tail if tail  # Return nil if tail is empty or nil, otherwise tail
  end

  def private?
    (@command == :privmsg) && (@params.first.eql? @bot.user.nick)
  end

  def replyTo
    @replyTo ||= private? ? nick : @params.first
  end

  def reply(text)
    return if !text
    s = text.to_s
    return if s.empty?
    return unless @command == :privmsg
    @bot.send "PRIVMSG #{replyTo} :#{s}"
  end

  def notice_user(text)
    return if !text
    s = text.to_s
    return if s.empty?
    return unless @command == :privmsg
    @bot.send "NOTICE #{nick} :#{s}"
  end

  def command_prefix
    '.'
  end

  def ctcp()
    return @ctcp if @ctcp
    msg = self.message
    return @ctcp = [] unless (@command == :privmsg || @command == :notice) && msg
    @ctcp = msg.scan(CTCP_REQUEST).flatten.map do |ctcp|
      ctcp_args = ctcp.split(' ')
      request = IRCMessage.normalize_ctcp_command(ctcp_args.shift)
      ctcp_args = ctcp_args.map { |arg| IRCMessage.ctcp_unquote(arg) } if ENCODED_COMMANDS.include? request
      {:command => request, :arguments => ctcp_args}
    end
  end

  def self.make_ctcp_message(command, arguments)
    command = normalize_ctcp_command(command)
    arguments = arguments.map { |arg| ctcp_quote(arg) } if ENCODED_COMMANDS.include? command
    "\01#{arguments.unshift(command).join(' ')}\01"
  end

  private

  # Format of an embedded CTCP request.
  CTCP_REQUEST = /\x01(.+?)\x01/
  # CTCP commands whose arguments are encoded according to the CTCP spec (as
  # opposed to other commands, whose arguments are plaintext).
  ENCODED_COMMANDS = [] # :VERSION and :PING don't seem to require that.

  def self.normalize_ctcp_command(cmd)
    cmd.upcase.to_sym
  end

  def self.ctcp_quote(str)
    str.gsub("\0", '\0').gsub("\1", '\1').gsub("\n", '\n').gsub("\r", '\r').gsub(" ", '\@').gsub("\\", '\\\\')
  end

  def self.ctcp_unquote(str)
    str.gsub('\0', "\0").gsub('\1', "\1").gsub('\n', "\n").gsub('\r', "\r").gsub('\@', " ").gsub('\\\\', "\\")
  end
end
