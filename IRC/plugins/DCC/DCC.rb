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

  COMMAND_KILL = :dcc_kill
  COMMAND_KILL_ALL = :dcc_kill!
  COMMAND_REGISTER = :dcc_reg
  COMMAND_UNREGISTER = :dcc_unreg

  attr_reader :parent_ircbot

  def commands
    result = {}
    if @plain_chat_info
      result[:chat] = 'sends a DCC CHAT request back to the caller'
    end
    if @secure_chat_info
      result[:schat] = 'sends a DCC SCHAT (SSL-encrypted chat) request back to the caller'
    end
    unless result.empty?
      result.merge!(
          {
              COMMAND_KILL => "allows to show and kill DCC connections from \
current user. When no arguments supplied, shows connections. Accepts any of: \
connection number (e.g. 12345), 'current' (kills current connection), \
'other' (kills all but current connection), 'all'. Example: .dcc_kill other",
              COMMAND_REGISTER => "associates given DCC connection \
credentials with the current IRC user. The credentials are given out on \
every DCC connection attempt from user.",
              COMMAND_UNREGISTER => "disassociates given DCC connection \
credentials from the current IRC user. The credentials are given out on \
every DCC connection from user.",
          })
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

  def on_privmsg(msg)
    bot_command = msg.botcommand
    case bot_command
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

      # User has the right to delete his credentials,
      # as well as all credentials, that resolve
      # to the same principals as the credentials
      # that he has now.
      allowed_credentials, allowed_principals = [msg.credentials, msg.principals]

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
    when COMMAND_KILL, COMMAND_KILL_ALL
      unless @router.check_permission(:can_use_dcc_chat, msg_to_principal(msg))
        msg.reply("Sorry, you don't have 'can_use_dcc_chat' permission.")
        return
      end

      unless msg.private?
        msg.reply('This command must be issued in private.')
        return
      end

      if COMMAND_KILL_ALL == bot_command
        unless @router.check_permission(:can_kill_any_dcc_connection, msg_to_principal(msg))
          msg.reply("Sorry, you don't have 'can_kill_any_dcc_connection' permission.")
          return
        end
        can_kill_anyone = true
      else
        can_kill_anyone = false
      end

      connections = get_connections()

      filter_allowed_connections!(connections, msg.principals, msg.credentials, can_kill_anyone)

      tail = msg.tail
      if tail
        kill_connections(connections, msg, tail.split)
      else
        list_connections(connections, msg)
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

  def get_affiliated_connections(bot)
    connections = get_connections()
    filter_allowed_connections!(connections, bot.principals, bot.credentials, false)
    connections
  end

  private

  def kill_connections(connections, msg, ports)
    kill_current_connection_too = false
    preserved_current_connection = false
    wrong_ports = []

    # kill connections with given ports
    ports = ports.map do |port|
      if port.to_i > 0
        [port.to_i]
      elsif port.casecmp('all') == 0
        kill_current_connection_too = true
        connections.keys
      elsif port.casecmp('other') == 0
        connections.keys
      elsif port.casecmp('current') == 0
        kill_current_connection_too = true
        []
      else
        wrong_ports << port
        []
      end
    end

    ports.flatten!
    ports.uniq!

    ports.each do |port|
      connection = connections[port.to_i]
      if connection
        bot = connection.bot
        type = connection.label
        if bot != msg.bot
          bot.close rescue nil
          msg.reply("Killed connection #{format_connection_info(bot, port, type)}")
        else
          preserved_current_connection = true
        end
      else
        wrong_ports << port
      end
    end

    unless wrong_ports.empty?
      msg.reply("Unknown connections: #{wrong_ports.uniq.join(', ')}.")
    end

    if kill_current_connection_too
      if msg.bot.instance_of?(DCCBot)
        msg.reply('Killing current connection...')
        msg.bot.close rescue nil
      end
    elsif preserved_current_connection
      msg.reply('Preserved current connection.')
    end
  end

  def list_connections(connections, msg)
    connections.each do |port, connection|
      bot = connection.bot
      type = connection.label
      msg.reply(format_connection_info(bot, port, type))
    end
    if connections.empty?
      msg.reply('No DCC connections present.')
    end
  end

  def filter_allowed_connections!(connections, allowed_principals, allowed_credentials, can_kill_anyone)
    unless can_kill_anyone
      connections.delete_if do |_, connection|
        !check_affiliation(connection.bot, allowed_credentials, allowed_principals)
      end
    end
  end

  def check_affiliation(bot, allowed_credentials, allowed_principals)
    !(
    (bot.principals & allowed_principals).empty? &&
        (bot.credentials & allowed_credentials).empty?
    )
  end

  def get_connections
    connections = {}
    merge_labeled(connections, @plain_chat_info, 'CHAT')
    merge_labeled(connections, @secure_chat_info, 'SCHAT')
    connections
  end

  def merge_labeled(map, submap, label)
    if submap
      labeled = submap.server.port_to_bot.map do |port, bot|
        [port, OpenStruct.new({:bot => bot, :label => label, :port => port})]
      end
      map.merge!(Hash[labeled])
    end
  end

  def format_connection_info(bot, port, type)
    "##{port}: Type: #{type}; Started: #{bot.start_time.utc}; Last used: #{bot.last_received_time.utc}; Principals: #{bot.principals.join(' ')}; Credentials: #{bot.credentials.join(' ')}"
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
