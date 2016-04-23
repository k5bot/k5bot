# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Stacked-functionality IO procuring plugin

require 'delegate'
require 'socket'
require 'openssl'

require 'IRC/Timer'
require 'IRC/IRCPlugin'

class Connectix
  include IRCPlugin
  DESCRIPTION = 'Stacked-functionality IO procuring plugin.'

  def self.get_connector_classes
    constants.map do |c|
      const_get(c)
    end.find_all do |c|
      c.is_a?(Class) && (c != Connector) && c.ancestors.include?(Connector)
    end
  end

  def self.normalize_connector_type(connector_type)
    connector_type.to_s.downcase
  end

  def self.get_connector_map
    Hash[get_connector_classes.map do |c|
      [normalize_connector_type(c.connector_type), c]
    end]
  end

  def get_connector_class(connector_type)
    @type_to_connector_class ||= self.class.get_connector_map
    @type_to_connector_class[self.class.normalize_connector_type(connector_type)]
  end

  def normalize_connector_id(connector_id)
    connector_id.to_sym
  end

  def ia(h, k)
    h[k] || h[k.to_s] # symbol/string indifferent hash access
  end

  def create_connector(connectors_hash, connector_class, connector_config)
    connector_type = connector_class.connector_type

    unless connector_config.is_a?(Hash)
      raise "Config for #{connector_type} connector must be a hash"
    end

    connector_name = ia(connector_config, :name)
    unless [String, Symbol].include?(ia(connector_config, :name).class)
      raise "Config for #{connector_type} connector must contain \
the 'name' key with the connector name string"
    end
    connector_name = normalize_connector_id(connector_name)
    if connectors_hash.include?(connector_name)
      raise "Duplicate connector name: #{connector_name}"
    end

    connector_uses = ia(connector_config, :uses)
    case connector_class::PARENT_SUPPORT
      when :none
        if connector_uses
          raise "Config for #{connector_name} can't contain 'uses' key"
        end
        connector_uses = []
      when :single
        connector_uses = case connector_uses
                        when Array
                          connector_uses
                        when String, Symbol
                          [connector_uses]
                        else
                          raise "Key 'uses' for #{connector_name} must contain a connector name."
                      end
        unless 1 == connector_uses.size
          raise "Key 'uses' for #{connector_name} must contain exactly one connector name."
        end
      when :multiple
        connector_uses = case connector_uses
                        when Array
                          connector_uses
                        when String, Symbol
                          [connector_uses]
                        else
                          raise "Key 'uses' for #{connector_name} must be an array of connector names."
                      end
        if connector_uses.empty?
          raise "Key 'uses' for #{connector_name} must contain at least one connector name."
        end
      else
        raise 'Bug!'
    end

    connectors_hash[connector_name] = connector_class.new(
        self,
        connector_name,
        connector_uses,
        connector_config
    )
  end

  def create_connectors(config)
    available_connectors = {}

    config.each do |group_name, connectors|
      connectors = connectors.map do |connector_type, connector_configs|
        connector_class = get_connector_class(connector_type)
        raise "Unknown connector type: #{connector_type}" unless connector_class
        [connector_class, connector_configs]
      end

      connectors = connectors.flat_map do |connector_class, connector_configs|
        unless connector_configs.is_a?(Array)
          connector_configs = [connector_configs]
        end

        connector_configs = connector_configs.each_with_index.map do |connector_config, index|
          index = (index>0) ? (index + 1).to_s : ''
          default_name = "#{group_name}.#{self.class.normalize_connector_type(connector_class.connector_type)}#{index}"
          connector_config ||= {}
          unless connector_config.is_a?(Hash)
            raise "Config for #{default_name} connector must be a hash"
          end
          name = ia(connector_config, :name)
          connector_config[:name] = default_name unless name
          connector_config
        end

        connector_configs.map do |oc|
          [connector_class, oc]
        end
      end

      connectors = connectors.group_by do |connector_class, _|
        connector_class::ORDER
      end.sort_by do |order, _|
        order
      end.map do |_, v|
        v
      end

      # Alias for the last connector in the group
      connectors << [[ConnectorAlias, { :name => group_name }]]

      connectors.each_cons(2) do |prev_group, cur_group|
        names = prev_group.map do |_, connector_config|
          ia(connector_config, :name)
        end
        cur_group.each do |_, connector_config|
          unless ia(connector_config, :uses)
            connector_config[:uses] = names
          end
        end
      end

      connectors.flatten(1).each do |connector_class, connector_config|
        create_connector(available_connectors, connector_class, connector_config)
      end
    end

    available_connectors.values.each do |connector|
      missing = connector.parent_connectors.map do |c|
        normalize_connector_id(c)
      end - available_connectors.keys

      unless missing.empty?
        raise "#{connector.id} depends on unknown connector(s): #{missing.join(' ')}"
      end
    end

    available_connectors
  end

  def afterLoad
    @available_connectors = create_connectors(@config)

    offence = nil
    @initialized_connectors = @available_connectors.values.take_while do |connector|
      begin
        connector.after_load
        true
      rescue Exception => e
        offence = e
        false
      end
    end
    raise offence if offence
  end

  def beforeUnload
    loop do
      connector = @initialized_connectors.pop
      break unless connector
      connector.before_unload rescue nil
    end

    @available_connectors = nil

    nil
  end

  # Public API method for opening a connection using given connector.
  # user_data can be used to supply connector-specific hints.
  def connectix_open(connector_id, user_data = {})
    connector_id = normalize_connector_id(connector_id)
    connector = @available_connectors[connector_id]
    raise "Can't find connector named #{connector_id}" unless connector
    unless user_data.is_a?(Hash)
      raise "User data must be a hash, received #{user_data.class.name}"
    end
    connector.open(user_data)
  end

  class Connector
    ORDER = 0
    PARENT_SUPPORT = :single # can also be :none or :multiple

    attr_reader :id, :config, :parent_connectors

    def initialize(owner, id, parent_connectors, config)
      @owner = owner
      @id = id
      @config = config
      @parent_connectors = parent_connectors
    end

    def after_load
    end

    def before_unload
    end

    def self.connector_type
      name.split('::').last[/^Connector(.*)/, 1]
    end

    LOG_MODE_PREFIX = {:log => '=', :in => '>', :out => '<', :error => '!'}
    def log(mode, text)
      puts "#{LOG_MODE_PREFIX[mode]}Connectix@#{self.class.connector_type}@#{id}: #{Time.now}: #{text}"
    end

    def ia(h, k)
      h[k] || h[k.to_s] # symbol/string indifferent hash access
    end
  end

  # Opens a tcp connection
  class ConnectorTCP < Connector
    PARENT_SUPPORT = :none

    DEFAULT_HOST_KEY = :host
    DEFAULT_PORT_KEY = :tcp_port

    def open(user_data)
      host = ia(@config, :host) || user_data[DEFAULT_HOST_KEY]
      port = ia(@config, :port) || user_data[DEFAULT_PORT_KEY]
      log(:log, "Connecting to host #{host} on port #{port}")
      TCPSocket.open(host, port)
    end
  end

  # Exposes a connector under a different name.
  # It's on the same level 0, as simple connectors, so it
  # can be conveniently used to inject more complex connectors
  # from other groups into the lowest level of current group.
  class ConnectorAlias < Connector
    def open(user_data)
      connector = @parent_connectors.first
      log(:log, "Redirecting to #{connector}")
      @owner.connectix_open(connector, user_data)
    end
  end

  # Picks one parent connector at random
  class ConnectorRandom < Connector
    ORDER = 1
    PARENT_SUPPORT = :multiple

    def open(user_data)
      connector = @parent_connectors.sample
      log(:log, "Picked #{connector}")
      @owner.connectix_open(connector, user_data)
    end
  end

  # Cycles through parent connectors in order, resetting to the start of
  # the list as soon as the last one tried is claimed to be successful
  # by using code. This prioritizes connectors at the start of the list,
  # since they will be first to be tried after connection closure or failure,
  class ConnectorFallback < Connector
    ORDER = 1
    PARENT_SUPPORT = :multiple

    module Wrapper
      def connectix_logical_success
        @_connectix_fallback_parent.logical_success
      end
    end

    def after_load
      @last_failed_connector = nil
    end

    def before_unload
      @last_failed_connector = nil
    end

    def logical_success
      # Successful connection.
      # Further reconnection attempts will try and start from
      # the beginning of the server list.
      log(:log, 'Received logical success confirmation.')
      @last_failed_connector = nil
    end

    def open(user_data)
      # Try to connect through the given connectors in order
      @last_failed_connector = if @last_failed_connector
                                 (@last_failed_connector + 1) % @parent_connectors.length
                               else
                                 0
                               end
      connector = @parent_connectors[@last_failed_connector]
      log(:log, "Picked #{connector}")
      connection = @owner.connectix_open(connector, user_data)
      connection.instance_variable_set(:@_connectix_fallback_parent, self)
      connection.extend(Wrapper)
      connection
    end
  end

  # Watches connection, opened by parent connector,
  # and forcibly closes it if its gets() method hasn't returned
  # for longer than configured timeout in seconds.
  class ConnectorWatchdog < Connector
    ORDER = 10 # We really want to be the last in the chain

    module Wrapper
      def gets
        begin
          v = super
          @_connectix_watchdog.push_back
          v
        rescue Exception => e
          @_connectix_watchdog.stop
          raise e
        end
      end

      def close
        begin
          super
        ensure
          @_connectix_watchdog.stop
        end
      end
    end

    def after_load
      @timeout = ia(@config, :timeout)
      unless @timeout.is_a?(Numeric)
        raise "'timeout' must be a number."
      end
    end

    def before_unload
      @timeout = nil
    end

    def open(user_data)
      connection = @owner.connectix_open(@parent_connectors.first, user_data)
      wrap_with_watchdog(connection)
    end

    def wrap_with_watchdog(io)
      watchdog = Timer.new(@timeout) do |timer|
        log(:error, "Watchdog interval (#{@timeout}) elapsed, forcibly closing io.")
        timer.stop
        io.close
      end
      io.instance_variable_set(:@_connectix_watchdog, watchdog)
      io.extend(Wrapper)
      io
    end
  end

  # Wraps connection, opened by parent connector, into client ssl socket,
  # possibly with supplied certificate and key, if so configured.
  class ConnectorSSL < Connector
    ORDER = 2

    module Wrapper
      # Forward all methods that looks like our customizations
      # to the underlying plain socket.

      def method_missing(m, *args, &block)
        return super unless m.to_s.start_with?('connectix')
        target = self.to_io
        target.respond_to?(m) ? target.__send__(m, *args, &block) : super
      end

      def respond_to_missing?(m, include_private)
        return super unless m.to_s.start_with?('connectix')
        target = self.to_io
        target.respond_to?(m, include_private) || super
      end
    end

    def after_load
      begin
        cert_file_name = ia(@config, :ssl_cert)
        cert_file = ssl_cert = nil
        if cert_file_name
          cert_file = File.read(cert_file_name)
          ssl_cert = OpenSSL::X509::Certificate.new(cert_file)
        end
      rescue => e
        raise "Failure reading SSL certificate: #{e.inspect}"
      end
      begin
        key_file = ia(@config, :ssl_key) ? File.read(ia(@config, :ssl_key)) : cert_file
        ssl_key = if key_file
                    OpenSSL::PKey::RSA.new(key_file, ia(@config, :ssl_key_passphrase))
                  end
      rescue => e
        raise "Failure reading SSL private key: #{e.inspect}"
      end

      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.cert = ssl_cert
      @ssl_context.key = ssl_key
      @ssl_context.ssl_version = :SSLv23
      #@ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER|OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
    end

    def before_unload
      @ssl_context = nil
    end

    def open(user_data)
      connection = @owner.connectix_open(@parent_connectors.first, user_data)
      OpenSSL::SSL::SSLSocket.new(connection, @ssl_context).tap do |socket|
        socket.sync_close = true
        socket.connect
        socket.extend(Wrapper)
      end
    end
  end
end
