# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client plugin

require 'base64'
require 'digest/sha2'

require 'ipaddr'
require 'socket'
require 'ostruct'

require_relative '../../IRCPlugin'

class DCC < IRCPlugin
  Description = 'Direct Client-to-Client protocol plugin.'
  Dependencies = [ :Router, :StorageYAML, :IRCBot ]

  DEFAULT_LISTEN_INTERFACE = '0.0.0.0'
  DEFAULT_LISTEN_PORT = 0 # Make OS choose a free port
  DEFAULT_CONNECTION_LIMIT = 10

  ACCESS_TIMESTAMP_KEY = :t
  ACCESS_PRINCIPAL_KEY = :p
  ACCESS_FORMER_PRINCIPAL_KEY = :w

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

      unless @router.check_permission(:can_use_dcc_chat, msg_to_principal(msg))
        msg.reply("Sorry, you don't have 'can_use_dcc_chat' permission.")
        return
      end

      reply = IRCMessage.make_ctcp_message(:DCC, ['CHAT', 'chat', @plain_chat_info.announce_ip, @plain_chat_info.server.port])
      msg.reply(reply, :force_private => true)
    when :schat
        return unless @secure_chat_info
        if msg.bot.instance_of?(DCCBot)
          msg.reply('Cannot initiate DCC chat from DCC chat.')
          return
        end

        unless @router.check_permission(:can_use_dcc_chat, msg_to_principal(msg))
          msg.reply("Sorry, you don't have 'can_use_dcc_chat' permission.")
          return
        end

        reply = IRCMessage.make_ctcp_message(:DCC, ['SCHAT', 'chat', @secure_chat_info.announce_ip, @secure_chat_info.server.port])
        msg.reply(reply, :force_private => true)
    when COMMAND_REGISTER
      unless @router.check_permission(:can_use_dcc_chat, msg_to_principal(msg))
        msg.reply("Sorry, you don't have 'can_use_dcc_chat' permission.")
        return
      end

      tail = msg.tail
      return unless tail

      principal = msg_to_principal(msg)
      credentials = tail.split

      credentials.each do |cred|
        if @dcc_access.include?(cred)
          if @dcc_access[cred][ACCESS_PRINCIPAL_KEY]
            msg.reply("DCC credential is already assigned to #{@dcc_access[cred][ACCESS_PRINCIPAL_KEY]}; Delete it first, using .#{COMMAND_UNREGISTER} #{cred}")
          else
            @dcc_access[cred] = {ACCESS_PRINCIPAL_KEY => principal, ACCESS_TIMESTAMP_KEY => Time.now.utc.to_i}
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
      unless @router.check_permission(:can_use_dcc_chat, msg_to_principal(msg))
        msg.reply("Sorry, you don't have 'can_use_dcc_chat' permission.")
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
        # to the same principals as the credentials
        # that he has now.
        allowed_principals = msg.bot.principals
      else
        # We're not under DCC, so user can only delete
        # credentials that resolve to the same principal
        # as him.
        allowed_principals = msg_to_principal(msg)
        allowed_credentials = []
      end

      credentials = tail.split

      credentials.each do |cred|
        ok = @dcc_access.include?(cred)
        ok &&= allowed_credentials.include?(cred) || allowed_principals.include?(@dcc_access[cred][ACCESS_PRINCIPAL_KEY])
        if ok
          was = @dcc_access[cred].delete(ACCESS_PRINCIPAL_KEY)
          if was
            @dcc_access[cred][ACCESS_FORMER_PRINCIPAL_KEY] = was
            msg.reply("Disassociated DCC credential: #{cred}")
          else
            msg.reply("DCC credential isn't associated: #{cred}")
          end
        else
          msg.reply("Unknown, invalid or not your DCC credential: #{cred}"  )
        end
      end

      store
    when :dcc_kill
      unless @router.check_permission(:can_kill_dcc_connection, msg_to_principal(msg))
        msg.reply("Sorry, you don't have 'can_kill_dcc_connection' permission.")
        return
      end
      unless msg.private?
        msg.reply("Respect people's privacy, do that in PM.")
        return
      end

      connections = {}

      merge_labeled(connections, @plain_chat_info, 'CHAT')
      merge_labeled(connections, @secure_chat_info, 'SCHAT')

      tail = msg.tail
      if tail
        # kill connections with given ports
        bots = tail.split.map {|port| [port, connections[port.to_i]]}
        bots.each do |port, connection|
          if connection
            bot = connection[0]
            type = connection[1]
            bot.close rescue nil
            msg.reply("Killed connection #{format_connection_info(bot, port, type)}")
          else
            msg.reply("Unknown connection '#{port}'.")
          end
        end
      else
        # output the list of connections
        connections.each do |port, connection|
          bot = connection[0]
          type = connection[1]
          msg.reply(format_connection_info(bot, port, type))
        end
        if connections.empty?
          msg.reply('No DCC connections present.')
        end
      end
    end
  end

  def msg_to_principal(msg)
    msg.prefix
  end

  def caller_id_to_credential(key)
    salt = (@config[:salt] || 'lame ass salt for those who did not set it themselves')
    Base64.strict_encode64(Digest::SHA2.digest(key.to_s + salt))
  end

  # Checks if credential is already stored and has associated principal,
  # otherwise mark it as being attempted for non-authorized access.
  def get_credential_authorization(credential)
    result = @dcc_access[credential]

    unless result
      result = @dcc_access[credential] = {ACCESS_TIMESTAMP_KEY => Time.now.utc.to_i}
      store
    end

    principal = result[ACCESS_PRINCIPAL_KEY]
    [principal, @router.check_permission(:can_use_dcc_chat, principal)] if principal
  end

  private

  def merge_labeled(map, submap, label)
    if submap
      labeled = submap.server.port_to_bot.map do |p, b|
        [p, [b, label]]
      end
      map.merge!(Hash[labeled])
    end
  end

  def format_connection_info(bot, port, type)
    "#{port}: #{type}; Principals: #{bot.principals.join(' ')}; Credentials: #{bot.credentials.join(' ')}"
  end

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

    OpenStruct.new({:server => server, :announce_ip => announce_ip})
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

    OpenStruct.new({:server => server, :announce_ip => announce_ip})
  end

  def stop_server(server_info)
    return unless server_info
    server_info.server.shutdown rescue nil
    server_info.server.join rescue nil
  end
end
