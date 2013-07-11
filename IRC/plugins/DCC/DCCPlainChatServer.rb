# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client plain chat server

require 'gserver'

class DCCPlainChatServer < GServer
  attr_reader :port_to_bot

  def initialize(dcc_plugin, port, host, max_connections)
    super(port, host, max_connections, nil, true, true)
    @dcc_plugin = dcc_plugin
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
    caller_info = caller_info.uniq

    do_log(:log, "Got incoming connection from #{caller_info}")

    client = DCCBot.new(client_socket, @dcc_plugin, @dcc_plugin.parent_ircbot)

    client.caller_info = caller_info
    client.credentials = caller_id.map { |key| @dcc_plugin.key_to_credential(key) }
    client.authorities = client.credentials.map { |cred| @dcc_plugin.check_credential_authorized(cred) }.reject { |x| !x }.uniq

    if client.authorities.empty?
      begin
        client.dcc_send('Unauthorized connection. Use command .chat_reg first.')

        caller_id.zip(client.credentials).each do |id, cred|
          client.dcc_send("To approve '#{id}' use: .#{DCC::COMMAND_REGISTER} #{cred}")
        end
      rescue Exception => e
        do_log(:error, "Exception while declining #{caller_info}: #{e.inspect}")
      end

      false
    else
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
      client.serve
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
