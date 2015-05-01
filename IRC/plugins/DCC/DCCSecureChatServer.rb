# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client SSL-encrypted chat server

require 'openssl'

class DCCSecureChatServer < DCCPlainChatServer

  def initialize(dcc_plugin, config)
    super(dcc_plugin, config)
    @dcc_plugin = dcc_plugin
    @config = config

    begin
      cert_file = File.read(@config[:ssl_cert])
      ssl_cert = OpenSSL::X509::Certificate.new(cert_file)
    rescue => e
      raise "Failure reading SSL certificate: #{e.inspect}"
    end
    begin
      key_file = @config[:ssl_key] ? File.read(@config[:ssl_key]) : cert_file
      ssl_key = OpenSSL::PKey::RSA.new(key_file, @config[:ssl_key_passphrase])
    rescue => e
      raise "Failure reading SSL private key: #{e.inspect}"
    end

    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.cert = ssl_cert
    @ssl_context.key = ssl_key
    #@ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT

=begin
    unless @ssl_context.session_id_context
      session_id = OpenSSL::Digest::MD5.hexdigest($0)
      @ssl_context.session_id_context = session_id
    end
=end
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

    client_socket = OpenSSL::SSL::SSLSocket.new(client_socket, @ssl_context)
    client_socket.sync_close = true
    client_socket.accept

    do_log(:log, "Completed SSL handshake with #{caller_info}")

    create_dcc_chat(client_socket, caller_id, credentials, principals, caller_info)
  end

  def socket_to_port(socket)
    # peeraddr() on SSLSocket doesn't take params.
    # Use to_io() to convert to the underlying TCPSocket.
    socket.to_io.peeraddr(false)[1]
  end
end
