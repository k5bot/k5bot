# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Web frontend plugin

require 'ostruct'

require 'webrick'
require 'webrick/https'

require 'IRC/IRCPlugin'

IRCPlugin.remove_required 'IRC/plugins/WebBot'
require 'IRC/plugins/WebBot/WebMessage'
require 'IRC/plugins/WebBot/WebLogger'
require 'IRC/plugins/WebBot/WebAuthFilterServlet'
require 'IRC/plugins/WebBot/WebBotServlet'
require 'IRC/plugins/WebBot/WebPlainChatServer'
require 'IRC/plugins/WebBot/WebSecureChatServer'

class WebBot
  include IRCPlugin
  DESCRIPTION = 'provides Web access to the bot'
  DEPENDENCIES = [:Router, :IRCBot, :Auth]

  USAGE_PERMISSION = :can_use_web_chat

  DEFAULT_LISTEN_INTERFACE = '0.0.0.0'
  DEFAULT_HTTP_LISTEN_PORT = 8080
  DEFAULT_HTTPS_LISTEN_PORT = 8443
  DEFAULT_CONNECTION_LIMIT = 10

  attr_reader :parent_ircbot, :start_time, :logger

  def commands
    result = {}
    if @plain_chat_info || @secure_chat_info
      result[:wchat] = 'shows http(s) url(s) to web interface.'
    end

    result
  end

  def afterLoad
    @start_time = Time.now

    @router = @plugin_manager.plugins[:Router]
    @auth = @plugin_manager.plugins[:Auth]
    @parent_ircbot = @plugin_manager.plugins[:IRCBot]
    @logger = WebLogger.new($stdout)

    @plain_chat_info = start_plain_server(merged_config(@config, :chat))
    begin
      @secure_chat_info = start_secure_server(merged_config(@config, :schat))
    rescue Exception
      stop_server(@plain_chat_info)
      raise
    end
  end

  def beforeUnload
    stop_server(@secure_chat_info)
    stop_server(@plain_chat_info)

    @secure_chat_info = nil
    @plain_chat_info = nil

    @logger = nil
    @parent_ircbot = nil
    @auth = nil
    @router = nil

    @start_time = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
      when :wchat
        return unless @plain_chat_info || @secure_chat_info

        unless check_access(msg_to_principal(msg))
          msg.reply("Sorry, you don't have '#{USAGE_PERMISSION}' permission.")
          return
        end

        reply = []
        add_link(reply, 'http', @plain_chat_info, 80)
        add_link(reply, 'https', @secure_chat_info, 443)

        reply = "Web chat: #{reply.join(' ')}"
        msg.reply(reply, :force_private => true)
    end
  end

  def dispatch(msg)
    @router.dispatch_message(msg)
  end

  def caller_id_to_credential(key)
    @auth.hash_credential(key)
  end

  # Checks if credential is already stored and has associated principal,
  # otherwise mark it as being attempted for non-authorized access.
  def get_credential_authorization(credential)
    principal = @auth.get_principal_by_credential(credential)
    [principal, check_access(principal)] if principal
  end

  private

  def check_access(principal)
    @auth.check_direct_access_permission(principal) &&
        @auth.check_permission(USAGE_PERMISSION, principal)
  end

  def msg_to_principal(msg)
    msg.principals.first
  end

  def add_link(reply, type, config, default_port)
    return unless config
    address = config.announce_address
    port = config.announce_port
    reply << type + '://' + address + "#{":#{port}" unless port.eql?(default_port)}"
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

    announce_address = chat_config[:announce] || chat_config[:listen]
    unless announce_address
      raise "WEB CHAT configuration error! At least 'announce' or 'listen' ip must be defined."
    end

    server = WebPlainChatServer.new(self, chat_config)
    server.start

    OpenStruct.new({
                       :server => server,
                       :announce_address => announce_address,
                       :announce_port => server.server.config[:Port],
                   })
  end

  def start_secure_server(chat_config)
    return unless chat_config

    announce_address = chat_config[:announce] || chat_config[:listen]
    unless announce_address
      raise "WEB SCHAT configuration error! At least 'announce' or 'listen' ip must be defined."
    end

    unless chat_config[:ssl_cert]
      raise "WEB SCHAT configuration error! 'ssl_cert' must be defined."
    end

    server = WebSecureChatServer.new(self, chat_config)
    server.start

    OpenStruct.new({
                       :server => server,
                       :announce_address => announce_address,
                       :announce_port => server.server.config[:Port],
                   })
  end

  def stop_server(server_info)
    return unless server_info
    server_info.server.stop rescue nil
  end
end
