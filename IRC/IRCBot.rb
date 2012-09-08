# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCBot

require 'socket'
require_relative 'IRCUser'
require_relative 'IRCMessage'
require_relative 'IRCMessageRouter'
require_relative 'IRCFirstListener'
require_relative 'IRCUserPool'
require_relative 'IRCChannelPool'
require_relative 'IRCPluginManager'
require_relative 'Storage'

class IRCBot
  attr_reader :router, :userPool, :channelPool, :pluginManager, :storage, :config, :lastsent, :lastreceived, :startTime, :user

  def initialize(config = nil)
    @config = config || {
      :server => 'localhost',
      :port => 6667,
      :serverpass => nil,
      :username => 'bot',
      :nickname => 'bot',
      :realname => 'Bot',
      :userpass => nil,
      :channels => nil,
      :plugins  => nil,
      :datadirectory => nil
    }

    @config.freeze  # Don't want anything modifying this

    @storage = Storage.new @config[:datadirectory] # Add storage

    @user = IRCUser.new(@config[:username], nil, @config[:realname], @config[:nickname])

    @router = IRCMessageRouter.new self
    @router.register self

    @firstListener = IRCFirstListener.new self  # Set first listener
    @userPool = IRCUserPool.new self  # Add user pool
    @channelPool = IRCChannelPool.new self  # Add channel pool
    @pluginManager = IRCPluginManager.new self  # Add plugin manager
    @pluginManager.loadPlugins @config[:plugins]  # Load plugins

    $stdout.sync = true
  end

  def configure
    yield @config
  end

  def send(raw)
    raw = encode raw
    raw.gsub!(/[\n]+/, ' ')
    raw.strip!
    raw = raw[0, 512] # Trim to max 512 characters
    @lastsent = raw
    str = raw.dup
    str.gsub!(@config[:serverpass], '*****') if @config[:serverpass]
    str.gsub!(@config[:userpass], '*****') if @config[:userpass]
    puts "#{timestamp} \e[#34m#{str}\e[0m"
    @sock.write "#{raw}\r\n"
  end

  def receive(raw)
    raw = encode raw
    @lastreceived = raw
    puts "#{timestamp} #{raw}"
    @router.route IRCMessage.new(self, raw.chomp)
  end

  def timestamp
    "\e[#37m#{Time.now}\e[0m"
  end

  def start
    @startTime = Time.now
    begin
      @sock = TCPSocket.open @config[:server], @config[:port]
      login
      until @sock.eof? do # Throws Errno::ECONNRESET
        receive @sock.gets
      end
    rescue SocketError, Errno::ECONNRESET => e
      puts "Cannot connect: #{e}"
    end
  end

  def on_notice(msg)
    if msg.message && (msg.message =~ /^You are now identified for .*#{@config[:username]}.*\.$/)
      joinChannels
    end
  end

  private
  def login
    send "PASS #{@config[:serverpass]}" if @config[:serverpass]
    send "NICK #{@config[:nickname]}" if @config[:nickname]
    send "USER #{@config[:username]} 0 * :#{@config[:realname]}" if @config[:username] && @config[:realname]
    if @config[:userpass]
      send "PRIVMSG NickServ :IDENTIFY #{@config[:username]} #{@config[:userpass]}"
    else
      joinChannels
    end
  end

  def joinChannels
    send "JOIN #{@config[:channels]*','}" if @config[:channels]
  end

  # Checks to see if a string looks like valid UTF-8.
  # If not, it is re-encoded to UTF-8 from assumed CP1252.
  # This is to fix strings like "abcd\xE9f".
  def encode(str)
    str.force_encoding('UTF-8')
    if !str.valid_encoding?
      str.force_encoding('CP1252').encode!("UTF-8", {:invalid => :replace, :undef => :replace})
    end
    str
  end
end
