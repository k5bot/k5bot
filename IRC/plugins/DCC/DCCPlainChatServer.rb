# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client plain chat server

require 'gserver'

require 'IRC/ContextMetadata'

class DCCPlainChatServer < GServer
  attr_reader :port_to_bot
  attr_reader :config

  def initialize(dcc_plugin, config)
    super(config[:port] || dcc_plugin.class::DEFAULT_LISTEN_PORT,
          config[:listen] || dcc_plugin.class::DEFAULT_LISTEN_INTERFACE,
          config[:limit] || dcc_plugin.class::DEFAULT_CONNECTION_LIMIT,
          nil, true, true)

    @dcc_plugin = dcc_plugin
    @config = config

    @port_to_bot = {}
  end

  def starting
  end

  def stopping
  end

  def connecting(client_socket)
    caller_info = client_socket.peeraddr(true)
    # [host, ip] or [ip], if reverse resolution failed
    caller_id = caller_info[2..-1].uniq
    # [family, port, host, ip] or [family, port, ip]
    caller_info = caller_info.uniq

    do_log(:log, "Got incoming connection from #{caller_info}")

    credentials = caller_id.map { |id_part| @dcc_plugin.caller_id_to_credential(id_part) }
    authorizations = credentials.map { |cred| @dcc_plugin.get_credential_authorization(cred) }.reject { |x| !x }

    principals = authorizations.map { |principal, _| principal }.uniq

    unless authorizations.empty? || authorizations.any? { |_, is_authorized| is_authorized }
      do_log(:log, "Identified #{caller_info} as non-authorized #{principals}")
      # Drop connection immediately.
      return
    end

    create_dcc_chat(client_socket, caller_id, credentials, principals, caller_info)
  end

  def create_dcc_chat(client_socket, caller_id, credentials, principals, caller_info)
    client = DCCBot.new(client_socket, @dcc_plugin, @dcc_plugin.parent_ircbot)

    client.caller_info = caller_info
    client.credentials = credentials
    client.principals = principals

    if client.principals.empty?
      begin
        client.dcc_send("Unauthorized connection. Use command .#{Auth::COMMAND_REGISTER} first.")

        caller_id.zip(client.credentials).each do |id, cred|
          client.dcc_send("To approve '#{id}' use: .#{Auth::COMMAND_REGISTER} #{cred}")
        end
      rescue Exception => e
        do_log(:error, "Exception while declining #{caller_info}: #{e.inspect}")
      end

      false
    else
      connections = @dcc_plugin.get_affiliated_connections(client)

      client.dcc_send("Hello! You're authorized as: #{principals.join(' ')}; Credentials: #{credentials.join(' ')}")

      if @config[:hard_limit] && connections.size >= @config[:hard_limit]
        client.dcc_send("Exceeded per-user connection limit (#{@config[:hard_limit]}). Killing oldest connection. See also '.help #{@dcc_plugin.class::COMMAND_KILL}'")

        connections = connections.values.sort_by do |connection|
          connection.bot.last_received_time
        end.to_a

        while connections.size >= @config[:hard_limit]
          connection = connections.shift
          connection.bot.close rescue nil
        end
      elsif @config[:soft_limit] && connections.size >= @config[:soft_limit]
        if @config[:hard_limit]
          client.dcc_send("You have #{connections.size+1} active connections. \
When this number exceeds #{@config[:hard_limit]}, older connections will be killed. \
See also '.help #{@dcc_plugin.class::COMMAND_KILL}'")
        else
          client.dcc_send("You have #{connections.size+1} active connections. \
See '.help #{@dcc_plugin.class::COMMAND_KILL}'")
        end
      end

      @port_to_bot[socket_to_port(client_socket)] = client

      true
    end
  end

  def disconnecting(client_port)
    @port_to_bot.delete(client_port)

    do_log(:log, "Closing connection to #{client_port}")
  end

  def serve(client_socket)
    client_port = socket_to_port(client_socket)
    client = @port_to_bot[client_port]
    if client
      ContextMetadata.run_with(@config[:metadata]) do
        client.serve
      end
    else
      raise "Bug! #{self.class.to_s} attempted to serve unknown client on port #{client_port}"
    end
  end

  # Hack around Gserver's criminal inability
  # to properly force clients to stop.
  def shutdown
    # Mark gserver as shutting down.
    # This is so that it won't start raising
    # exceptions in client threads,
    super

    # Close listening socket to avoid hanging on accept()
    # indefinitely, while join()ing on server thread.
    @tcpServer.shutdown

    # Signal all clients to close
    while @connections.size > 0
      @port_to_bot.values.each do |client|
        client.close rescue nil
      end
      sleep(1)
    end
  end

  def error(e)
    do_log(:error, "#{e.inspect} #{e.backtrace.join("\n") rescue nil}")
  end

  def log(text)
    do_log(:log, text)
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def do_log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}DCC: #{Time.now}: #{self.class.to_s}: #{text}"
  end

  def socket_to_port(socket)
    socket.peeraddr(false)[1]
  end
end
