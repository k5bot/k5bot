# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# HTTPS server wrapper

class WebBot
class WebSecureChatServer < WebPlainChatServer
  def generate_server_config(plugin_instance, config)
    result = super(plugin_instance, config)

    begin
      cert_file = File.read(config[:ssl_cert])
      ssl_cert = OpenSSL::X509::Certificate.new(cert_file)
    rescue => e
      raise "Failure reading SSL certificate: #{e.inspect}"
    end
    begin
      key_file = config[:ssl_key] ? File.read(config[:ssl_key]) : cert_file
      ssl_key = OpenSSL::PKey::RSA.new(key_file, config[:ssl_key_passphrase])
    rescue => e
      raise "Failure reading SSL private key: #{e.inspect}"
    end

    result.merge(
        :Port => config[:port] || plugin_instance.class::DEFAULT_HTTPS_LISTEN_PORT,
        :SSLEnable => true,
        :SSLCertificate => ssl_cert,
        :SSLPrivateKey => ssl_key,
    )
  end

  def get_caller_info(client_socket)
    # peeraddr() on SSLSocket doesn't take params.
    # Use to_io() to convert to the underlying TCPSocket.
    client_socket.to_io.peeraddr(true)
  end
end
end