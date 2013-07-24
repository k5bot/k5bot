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

require 'ostruct'

class IRCMessage
  attr_reader :prefix,
              :command,
              :params,
              :timestamp,
              :bot,
              :bot_command, # The first word of the message if it starts with 'command_prefix'
              :ctcp, # array of OpenStructs, representing CTCPs passed inside the message.
              :tail # The message with nick prefix and botcommand removed if it exists, otherwise the whole message

  def initialize(bot, raw)
    @prefix, @command, @params, @user, @ctcp, @bot_command, @tail, @is_private = nil
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

    if @command == :privmsg || @command == :notice
      @is_private = @params.first.eql?(@bot.user.nick)

      @ctcp = if message
                message.scan(CTCP_REQUEST).flatten.map do |ctcp|
                  request, ctcp = ctcp.split(/ +/, 2)
                  request = IRCMessage.normalize_ctcp_command(request)
                  ctcp_args = (ctcp || '').split(/ +/)
                  if ENCODED_COMMANDS.include?(request)
                    ctcp_args = ctcp_args.map { |arg| IRCMessage.ctcp_unquote(arg) }
                  end
                  OpenStruct.new({:command => request, :arguments => ctcp_args, :raw => ctcp})
                end
              end

      # Since most plugins that implement on_privmsg() don't (properly) handle ctcp anyway,
      # redirect those as two separate commands :ctcp_privmsg and :ctcp_notice
      @command = "ctcp_#{@command}".to_sym unless @ctcp.empty?
    end

    if @command == :privmsg
      m = message && message.match(/^\s*(#{@bot.user.nick}\s*[:>,]?\s*)?#{command_prefix_matcher}([\p{ASCII}\uFF01-\uFF5E&&[^\p{Z}]]+)\p{Z}*(.*)\s*/i)

      if m
        bc = m[2]
        @bot_command = bc.tr("\uFF01-\uFF5E", "\u{21}-\u{7E}").downcase.to_sym if bc
      end

      tail = (m && m[3]) || message
      @tail = tail.empty? ? nil : tail
    end
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

  # Deprecated. Backward compatibility for bot_command.
  def botcommand
    @bot_command
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

  def private?
    @is_private
  end

  def replyTo(*force_private)
    @replyTo ||= (private? || force_private.first) ? nick : @params.first
  end

  def reply(text, opts = {})
    return unless can_reply?
    return if !text
    text = text.to_s
    return if text.empty?

    @bot.send(opts.merge(:original=>"PRIVMSG #{replyTo(opts[:force_private])} :#{text}"))
  end

  def notice_user(text)
    return if !text
    s = text.to_s
    return if s.empty?
    return unless can_reply?
    @bot.send "NOTICE #{nick} :#{s}"
  end

  def can_reply?
    @command == :privmsg || @command == :ctcp_privmsg
  end

  def command_prefix
    '.'
  end

  def command_prefix_matcher
    /[.．｡。]/.to_s
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
