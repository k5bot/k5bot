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
  Commands = {
    :chat => 'convenience command that sends a DCC chat request back to the caller',
  }
  Dependencies = [ :Router, :StorageYAML, :IRCBot ]

  DEFAULT_LISTEN_INTERFACE = '0.0.0.0'
  DEFAULT_LISTEN_PORT = 55554

  attr_reader :parent_ircbot

  def afterLoad
    unless @config[:announce] || @config[:listen]
      raise "DCC configuration error! At least 'announce' or 'listen' ip must be defined."
    end

    @announce_ip = IPAddr.new(@config[:announce] || @config[:listen]).to_i
    @announce_port = @config[:port] || DEFAULT_LISTEN_PORT

    load_helper_class(:DCCMessage)
    load_helper_class(:DCCBot)

    @storage = @plugin_manager.plugins[:StorageYAML]
    @router = @plugin_manager.plugins[:Router]
    @parent_ircbot = @plugin_manager.plugins[:IRCBot]

    @dcc_access = @storage.read('dcc_access') || {}

    @tcp_server = TCPServer.new(@config[:listen] || DEFAULT_LISTEN_INTERFACE, @announce_port)

    @listen_thread = Thread.start(self) do |dcc_instance|
      listen_thread_body(dcc_instance, @parent_ircbot)
    end
  end

  def beforeUnload
    @tcp_server.shutdown rescue nil
    @tcp_server = nil

    (@listen_thread.join unless Thread.current.eql?(@listen_thread)) rescue nil
    @listen_thread = nil

    @dcc_access = nil
    @router = nil
    @storage = nil

    unload_helper_class(:DCCBot)
    unload_helper_class(:DCCMessage)

    @announce_port = nil
    @announce_ip = nil

    nil
  end

  def store
    @storage.write('dcc_access', @dcc_access)
  end

  def listen_thread_body(dcc_plugin, parent_ircbot)
    clients = []
    begin
      loop do
        client = DCCBot.new(@tcp_server.accept, dcc_plugin, parent_ircbot)

        client.credentials = client.caller_id.map { |key| key_to_credential(key) }
        client.authorities = client.credentials.map { |cred| check_credential_authorized(cred) }.reject { |x| !x }.uniq

        if client.authorities.empty?
          begin
            client.dcc_send('Unauthorized connection. Use command .chat_reg first.')

            client.caller_id.zip(client.credentials).each do |id, cred|
              client.dcc_send("To approve '#{id}' use: .#{DCC::COMMAND_REGISTER} #{cred}")
            end
          rescue Exception => e
            puts "=DCC: Exception while declining unauthorized access: #{e.inspect}"
          ensure
            client.close
          end
          next
        end

        client.start

        clients << client
        clients.delete_if do |c|
          if c.is_dead?
            c.close
            true
          end
        end
      end
    ensure
      clients.each do |client|
        client.close rescue nil
      end
    end
  end

  def dispatch(msg)
    @router.dispatch_message(msg)
  end

  COMMAND_REGISTER = :chat_reg
  COMMAND_UNREGISTER = :chat_unreg

  def on_privmsg(msg)
    case msg.botcommand
    when :chat
      if msg.bot.instance_of?(DCCBot)
        msg.reply('Cannot initiate DCC chat from DCC chat.')
        return
      end

      unless @router.check_permission(:can_use_dcc_chat, msg)
        msg.reply("Sorry, you don't have the permission to use DCC chat.")
        return
      end

      reply = IRCMessage.make_ctcp_message(:DCC, ['CHAT', 'chat', @announce_ip, @announce_port])
      msg.reply(reply, :force_private => true)
    when COMMAND_REGISTER
      unless @router.check_permission(:can_use_dcc_chat, msg)
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
      unless @router.check_permission(:can_use_dcc_chat, msg)
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

  private

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
end
