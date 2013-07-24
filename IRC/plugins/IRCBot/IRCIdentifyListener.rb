# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCIdentifyListener is the listener that handles NickServ interaction

require 'ostruct'

require_relative '../../IRCListener'

class IRCIdentifyListener
  include IRCListener

  def initialize(bot, config)
    @bot = bot
    @config = ({:service => 'NickServ'}.merge(config) if config)
    @logged_in = nil

    auth_identify_check_config(@config)
  end

  def check_not_empty(hash, key, text)
    field = hash[key]
    raise "Configuration error! Field '#{key}' in #{text} can't be empty." unless field && !field.empty?
    field
  end

  def auth_identify_check_config(config)
    return unless config

    check_not_empty(config, :login, 'identify')
    check_not_empty(config, :password, 'identify')
    check_not_empty(config, :service, 'identify')

    # check that regexps parse ok
    Regexp.new(config[:invitation]) if config[:invitation]
    Regexp.new(config[:confirmation]) if config[:confirmation]
  end

  # This method is overridden, so that command-methods can
  # pass back their own return values.
  def receive_message(msg)
    dispatch_message_to_methods(msg)
  end

  def on_connection(msg)
    return if @logged_in
    @logged_in = true

    # If user hasn't specified invitation regexp,
    # identify immediately and unconditionally.
    unless @config && @config[:invitation]
      auth_identify()
    end

    # Stop connection event propagation,
    # if user requested to wait for confirmation.
    @config && @config[:confirmation]
  end

  def on_disconnection(msg)
    @logged_in = false

    nil
  end

  def on_notice(msg)
    return unless @config
    return unless msg.message && msg.nick && (msg.nick.casecmp(@config[:service]) == 0)

    if @config[:invitation] && msg.message =~ Regexp.new(@config[:invitation])
      auth_identify()
    elsif @config[:confirmation] && msg.message =~ Regexp.new(@config[:confirmation])
      @bot.dispatch(OpenStruct.new({:command => :connection}))
    end

    nil
  end

  def auth_identify
    return unless @config

    reply = {
      :original => "PRIVMSG #{@config[:service]} :IDENTIFY #{@config[:login]} #{@config[:password]}",
      :log_hide => "PRIVMSG #{@config[:service]} :IDENTIFY #{@config[:login]} *USP*"
    }
    @bot.send_raw(reply)
  end

  LISTENER_PRIORITY = -31

  def listener_priority
    LISTENER_PRIORITY
  end
end
