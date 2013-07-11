# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client plugin

require 'base64'
require 'digest/sha2'

require 'ipaddr'
require 'socket'

require_relative '../../IRCPlugin'

class DCC < IRCPlugin
  Description = 'Direct Client-to-Client protocol plugin.'
  Dependencies = [ :Router, :StorageYAML, :IRCBot ]

  DEFAULT_LISTEN_INTERFACE = '0.0.0.0'
  DEFAULT_LISTEN_PORT = 0 # Make OS choose a free port
  DEFAULT_CONNECTION_LIMIT = 10

  attr_reader :parent_ircbot

  def commands
    result = {}
    if @plain_chat_info
      result[:chat] = 'sends a DCC CHAT request back to the caller'
    end
    if @secure_chat_info
      result[:schat] = 'sends a DCC SCHAT (SSL-encrypted chat) request back to the caller'
    end

    result
  end

  def afterLoad
    load_helper_class(:DCCMessage)
    load_helper_class(:DCCBot)
    load_helper_class(:DCCPlainChatServer)
    load_helper_class(:DCCSecureChatServer)

    @storage = @plugin_manager.plugins[:StorageYAML]
    @router = @plugin_manager.plugins[:Router]
    @parent_ircbot = @plugin_manager.plugins[:IRCBot]
    @dcc_access = @storage.read('dcc_access') || {}

    @plain_chat_info = start_plain_server(merged_config(@config, :chat))
    @secure_chat_info = start_secure_server(merged_config(@config, :schat))
  end

  def beforeUnload
    stop_server(@secure_chat_info)
    stop_server(@plain_chat_info)

    @dcc_access = nil
    @parent_ircbot = nil
    @router = nil
    @storage = nil

    unload_helper_class(:DCCSecureChatServer)
    unload_helper_class(:DCCPlainChatServer)
    unload_helper_class(:DCCBot)
    unload_helper_class(:DCCMessage)

    nil
  end

  def store
    @storage.write('dcc_access', @dcc_access)
  end

  def dispatch(msg)
    @router.dispatch_message(msg)
  end

  COMMAND_REGISTER = :chat_reg
  COMMAND_UNREGISTER = :chat_unreg

  def on_privmsg(msg)
    case msg.botcommand
    when :chat
      return unless @plain_chat_info
      if msg.bot.instance_of?(DCCBot)
        msg.reply('Cannot initiate DCC chat from DCC chat.')
        return
      end

      unless @router.check_permission(:can_use_dcc_chat, msg.prefix)
        msg.reply("Sorry, you don't have the permission to use DCC chat.")
        return
      end

      reply = IRCMessage.make_ctcp_message(:DCC, ['CHAT', 'chat', @plain_chat_info[1], @plain_chat_info[0].port])
      msg.reply(reply, :force_private => true)
    when :schat
        return unless @secure_chat_info
        if msg.bot.instance_of?(DCCBot)
          msg.reply('Cannot initiate DCC chat from DCC chat.')
          return
        end

        unless @router.check_permission(:can_use_dcc_chat, msg.prefix)
          msg.reply("Sorry, you don't have the permission to use DCC chat.")
          return
        end

        reply = IRCMessage.make_ctcp_message(:DCC, ['SCHAT', 'chat', @secure_chat_info[1], @secure_chat_info[0].port])
        msg.reply(reply, :force_private => true)
    when COMMAND_REGISTER
      unless @router.check_permission(:can_use_dcc_chat, msg.prefix)
        msg.reply("Sorry, you don't have the permission to use DCC chat.")
        return
      end

      tail = msg.tail
      return unless tail

      authority = msg_to_authority(msg)
      credentials = tail.split

      credentials.each do |cred|
        if @dcc_access.include?(cred)
          if @dcc_access[cred][:a]
            msg.reply("DCC credential is already assigned to #{@dcc_access[cred][:a]}; Delete it first, using .#{COMMAND_UNREGISTER} #{cred}")
          else
            @dcc_access[cred] = {:a => authority, :t => Time.now.utc.to_i}
            msg.reply("Associated you with DCC credential: #{cred}")
          end
        else
          # Credential should be touched by actual attempt to connect first,
          # To prevent database pollution with random credentials.
          msg.reply("Unknown or invalid DCC credential: #{cred}")
        end
      end

      store
    when COMMAND_UNREGISTER
      unless @router.check_permission(:can_use_dcc_chat, msg.prefix)
        msg.reply("Sorry, you don't have the permission to use DCC chat.")
        return
      end

      tail = msg.tail
      return unless tail

      if msg.bot.instance_of?(DCCBot)
        # If we got this command from DCC, then user
        # has the right to delete credentials, that
        # his ip/host hash-compute to.
        allowed_credentials = msg.bot.credentials
        # As well as all credentials, that resolve
        # to the same authorities as the credentials he
        # has now.
        allowed_authorities = msg.bot.authorities
      else
        # We're not under DCC, so we can only delete
        # credentials that resolve to the same authority
        # as we have now.
        allowed_authorities = msg_to_authority(msg)
        allowed_credentials = []
      end

      credentials = tail.split

      credentials.each do |cred|
        ok = @dcc_access.include?(cred)
        ok &&= allowed_credentials.include?(cred) || allowed_authorities.include?(@dcc_access[cred][:a])
        if ok
          was = @dcc_access[cred].delete(:a)
          if was
            @dcc_access[cred][:w] = was
            msg.reply("Disassociated DCC credential: #{cred}")
          else
            msg.reply("DCC credential isn't associated: #{cred}")
          end
        else
          msg.reply("Unknown, invalid or not your DCC credential: #{cred}"  )
        end
      end

      store
    end
  end

  def msg_to_authority(msg)
    msg.prefix
  end

  def key_to_credential(key)
    salt = (@config[:salt] || 'lame ass salt for those who did not set it themselves')
    Base64.strict_encode64(Digest::SHA2.digest(key.to_s + salt))
  end

  def check_credential_authorized(credential)
    # checks if credential is already stored and has authorization,
    # otherwise mark it as being attempted for non-authorized access.
    result = @dcc_access[credential]

    unless result
      result = @dcc_access[credential] = {:t => Time.now.utc.to_i}
      store
    end

    result[:a]
  end

  private

  def merged_config(config, branch)
    return unless config.include?(branch)
    config = config.dup
    branch_config = config.delete(branch) || {}
    config.merge!(branch_config)
    config
  end

  def start_plain_server(chat_config)
    return unless chat_config

    unless chat_config[:announce] || chat_config[:listen]
      raise "DCC CHAT configuration error! At least 'announce' or 'listen' ip must be defined."
    end
    announce_ip = IPAddr.new(chat_config[:announce] || chat_config[:listen]).to_i
    server = DCCPlainChatServer.new(self, chat_config)
    server.start

    [server, announce_ip]
  end

  def start_secure_server(chat_config)
    return unless chat_config

    unless chat_config[:announce] || chat_config[:listen]
      raise "DCC SCHAT configuration error! At least 'announce' or 'listen' ip must be defined."
    end
    announce_ip = IPAddr.new(chat_config[:announce] || chat_config[:listen]).to_i
    unless chat_config[:ssl_cert]
      raise "DCC SCHAT configuration error! 'ssl_cert' must be defined."
    end
    server = DCCSecureChatServer.new(self, chat_config)
    server.start

    [server, announce_ip]
  end

  def stop_server(server_info)
    return unless server_info
    server_info[0].shutdown rescue nil
    server_info[0].join rescue nil
  end
end
