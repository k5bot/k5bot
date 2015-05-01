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

require_relative '../../../IRC/Message'
require_relative '../../../IRC/LayoutableText'

class IRCMessage
  include BotCore::Message

  attr_reader :prefix,
              :command,
              :params,
              :timestamp,
              :bot,
              :bot_command, # The first word of the message if it starts with 'command_prefix'
              :ctcp, # array of OpenStructs, representing CTCPs passed inside the message.
              :tail # The message with nick prefix and bot_command removed if it exists, otherwise the whole message

  def initialize(bot, raw)
    @raw = raw
    @bot = bot
    @prefix = @command = @params = nil
    @bot_command = @ctcp = @tail = nil
    @user = nil
    @is_private = @is_dedicated = nil
    @timestamp = Time.now
    parse(@raw)
  end

  def parse(raw)
    return unless raw
    raw.strip!
    msg_parts = raw.to_s.split(/[ 　]/)
    @prefix = msg_parts.shift[1..-1] if msg_parts.first.start_with?(':')
    @command = msg_parts.shift.downcase.to_sym
    @params = []
    @params << msg_parts.shift while msg_parts.first and !msg_parts.first.start_with?(':')
    msg_parts.first.slice!(0) if msg_parts.first
    @params.delete_if{|param| param.empty?}
    @params << msg_parts.join(' ') unless msg_parts.empty?

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
      m = if message
            # Try to find "[bot_nick:].command tail"
            /
^
\s*
(?<dedicated>#{@bot.user.nick}\s*[:>,]?\s*)?
#{command_prefix_matcher}
(?<command>[\p{ASCII}\uFF01-\uFF5E&&[^\p{Z}]]+)
\p{Z}*
(?<tail>.*)
$
            /ix.match(message) ||
            # If failed, try to find "bot_nick: tail"
            /
^
\s*
(?<dedicated>#{@bot.user.nick}\s*[:>,]?\s*)
(?<tail>.*)
$
             /ix.match(message)

            # This is done to always strip bot_nick,
            # if it is present, even if command isn't.
          end

      if m
        # Turn MatchData into a hash of named group captures.
        # This is so that we don't error out on m[:command]
        # when it's not present.
        m = Hash[m.names.map(&:to_sym).zip(m.captures)]

        # If bot nick is mentioned, consider this message dedicated
        @is_dedicated = !!m[:dedicated]

        bc = m[:command]
        @bot_command = bc.tr("\uFF01-\uFF5E", "\u{21}-\u{7E}").downcase.to_sym if bc
      end

      tail = m ? m[:tail] : message
      @tail = tail.empty? ? nil : tail

      @bot_command ||= :j if @is_private && !/^[\d０１２３４５６７８９\p{Z}]+$/.match(tail)
    end
  end

  def to_s
    @raw.dup
  end

  # Principals of the message originator
  def principals
    [@prefix]
  end

  # Credentials of the message originator
  def credentials
    []
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

  def dedicated?
    @is_private || @is_dedicated
  end

  def reply(text, opts = {})
    return unless can_reply?
    unless text.is_a?(LayoutableText)
      return unless text
      text = text.to_s
      return if text.empty?
      text = LayoutableText::SingleString.new(text)
    end

    cmd = opts[:notice] ? 'NOTICE' : 'PRIVMSG'
    reply_to = (private? || opts[:force_private]) ? nick : @params.first

    text = LayoutableText::Prefixed.new("#{cmd} #{reply_to} :", text)
    @bot.irc_send(text, opts)
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

  # Object that identifies the medium through which this message has passed.
  # This is useful to identify the group of people who may also have seen it,
  # and who will (or rather sensibly should) see our replies.
  def context
    # if public message, all the people in the channel saw it.
    # if private message, only the user in question did.
    [bot, private? ? user : channelname]
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
    str.gsub("\0", '\0').gsub("\1", '\1').gsub("\n", '\n').gsub("\r", '\r').gsub(' ', '\@').gsub("\\", '\\\\')
  end

  def self.ctcp_unquote(str)
    str.gsub('\0', "\0").gsub('\1', "\1").gsub('\n', "\n").gsub('\r', "\r").gsub('\@', ' ').gsub('\\\\', "\\")
  end
end
