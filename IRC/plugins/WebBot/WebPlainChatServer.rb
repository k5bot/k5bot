# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# HTTP server wrapper

require 'ostruct'

require_relative '../../ContextMetadata'

class WebPlainChatServer
  attr_reader :server

  def initialize(plugin_instance, config)
    @plugin_instance = plugin_instance
    @config = config

    # Add handler for erb files, which for some reason isn't among defaults.
    WEBrick::HTTPServlet::FileHandler.add_handler('erb', WEBrick::HTTPServlet::ERBHandler)

    @server = WEBrick::HTTPServer.new(generate_server_config(plugin_instance, config))

    mount('/',
          WEBrick::HTTPServlet::FileHandler,
          [
              "#{@plugin_instance.plugin_root}/public_html",
              {
                  :FancyIndexing => false,
              },
          ],
          :UnknownUserDelegate => WEBrick::HTTPServlet::ERBHandler.get_instance(
              @server,
              "#{@plugin_instance.plugin_root}/public_html/unauthorized.html.erb"
          )
    )

    mount('/api/query',
          WebBotServlet,
          [plugin_instance, @plugin_instance.parent_ircbot])

    @thread = nil
  end

  def generate_server_config(plugin_instance, config)
    {
        :BindAddress => config[:listen] || plugin_instance.class::DEFAULT_LISTEN_INTERFACE,
        :Port => config[:port] || plugin_instance.class::DEFAULT_HTTP_LISTEN_PORT,
        :MaxClients => config[:limit] || plugin_instance.class::DEFAULT_CONNECTION_LIMIT,
        :DirectoryIndex => %w(index.html.erb index.html index.htm),
        :Logger => plugin_instance.logger,
        :AccessLog => [[$stdout, '=WEB: %{%Y-%m-%d %H:%M:%S %z}t: ACCESS: %u "%r" %s %b']]
        #:RequestTimeout => 300, # give some slack to slow plugins
    }
  end

  def mount(dir, servlet, options, auth_opts = {})
    @server.mount(dir,
                  WebAuthFilterServlet,
                  {
                      :Delegate => servlet,
                      :DelegateOptions => options
                  }.update(auth_opts))
  end

  def start
    return if @thread

    @thread = Thread.new() do
      @server.start do |sock|
        auth = get_ip_auth(sock)

        ContextMetadata.run_with(WebAuthFilterServlet::WEB_USER_AUTH_KEY => auth) do
          @server.run(sock)
        end
      end
    end
  end

  def stop
    if @thread
      @server.shutdown
      @thread.join unless Thread.current.eql?(@thread)
      @thread = nil
    end
  end

  def get_ip_auth(client_socket)
    caller_info = get_caller_info(client_socket)
    # [host, ip] or [ip], if reverse resolution failed
    caller_id = caller_info[2..-1].uniq
    # [family, port, host, ip] or [family, port, ip]
    caller_info = caller_info.uniq

    credentials = caller_id.map { |id_part| @plugin_instance.caller_id_to_credential(id_part) }
    authorizations = credentials.map { |cred| @plugin_instance.get_credential_authorization(cred) }.reject { |x| !x }

    principals = authorizations.map { |principal, _| principal }.uniq

    OpenStruct.new({
                       :caller_id => caller_id,
                       :principals => principals,
                       :credentials => credentials,
                       :authorizations => authorizations,
                   })
  end

  def get_caller_info(client_socket)
    client_socket.peeraddr(true)
  end
end
