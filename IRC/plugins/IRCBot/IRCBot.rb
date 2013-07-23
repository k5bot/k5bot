# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCBot

require 'socket'
require 'ostruct'

require_relative '../../Timer'
require_relative '../../Throttler'
require_relative '../../IRCPlugin'
require_relative '../../ContextMetadata'

require_relative 'IRCUser'
require_relative 'IRCMessage'
require_relative 'IRCLoginListener'
require_relative 'IRCFirstListener'

class IRCBot < IRCPlugin

  Description = 'Provides IRC connectivity.'

  Dependencies = [ :ChannelPool, :Router, :StorageYAML ]

  attr_reader :last_sent, :last_received, :start_time, :user

  def afterLoad
    load_helper_class(:IRCUser)
    load_helper_class(:IRCMessage)
    load_helper_class(:IRCCapsListener)
    load_helper_class(:IRCServerPassListener)
    load_helper_class(:IRCUserListener)
    load_helper_class(:IRCLoginListener)
    load_helper_class(:IRCIdentifyListener)
    load_helper_class(:IRCJoinListener)
    load_helper_class(:IRCFirstListener)

    @config = {
      :server => 'localhost',
      :port => 6667,
      :serverpass => nil,
      :username => 'bot',
      :nickname => 'bot',
      :realname => 'Bot',
      :channels => nil,
      :plugins  => nil,
    }.merge!(@config)

    @config.freeze  # Don't want anything modifying this

    @throttler = Throttler.new(@config[:burst] || 0, @config[:rate] || 0)

    @user = IRCUser.new(@config[:username], nil, @config[:realname], @config[:nickname])

    @caps_listener = IRCCapsListener.new(self)
    @server_pass_listener = IRCServerPassListener.new(self, @config[:serverpass])
    @user_listener = IRCUserListener.new(@plugin_manager.plugins[:StorageYAML])
    @login_listener = IRCLoginListener.new(self, @config)
    @identify_listener = IRCIdentifyListener.new(self, @config[:identify])
    @join_listener = IRCJoinListener.new(self, @config[:channels])
    @first_listener = IRCFirstListener.new

    @additional_listeners = [
        @caps_listener,
        @server_pass_listener,
        @user_listener,
        @login_listener,
        @identify_listener,
        @join_listener,
        @first_listener,
    ]

    @channel_pool = @plugin_manager.plugins[:ChannelPool] # Get channel pool
    @router = @plugin_manager.plugins[:Router] # Get router

    @watchdog = nil

    @last_failed_server = nil
  end

  def beforeUnload
    return "Can't unload before connection is killed" if @sock

    @router = nil
    @channel_pool = nil

    @first_listener = nil
    @join_listener = nil
    @identify_listener = nil
    @login_listener = nil
    @user_listener = nil
    @server_pass_listener = nil
    @caps_listener = nil

    @user = nil

    @throttler = nil

    unload_helper_class(:IRCFirstListener)
    unload_helper_class(:IRCJoinListener)
    unload_helper_class(:IRCIdentifyListener)
    unload_helper_class(:IRCLoginListener)
    unload_helper_class(:IRCUserListener)
    unload_helper_class(:IRCServerPassListener)
    unload_helper_class(:IRCCapsListener)
    unload_helper_class(:IRCMessage)
    unload_helper_class(:IRCUser)

    nil
  end

  #truncates truncates a string, so that it contains no more than byte_limit bytes
  #returns hash with key :truncated, containing resulting string.
  #hash is used to avoid double truncation and for future truncation customization.
  def truncate_for_irc(raw, byte_limit)
    if raw.instance_of?(Hash)
      return raw if raw[:truncated] #already truncated
      opts = raw
      raw = raw[:original]
    else
      opts = {:original => raw}
    end
    raw = encode raw.dup

    #char-per-char correspondence replace, to make the returned count meaningful
    raw.gsub!(/[\r\n]/, ' ')
    raw.strip!

    #raw = raw[0, 512] # Trim to max 512 characters
    #the above is wrong. characters can be of different size in bytes.

    truncated = raw.byteslice(0, byte_limit)

    #the above might have resulted in a malformed string
    #try to guess the necessary resulting length in chars, and
    #make a clean cut on a character boundary
    i = truncated.length
    loop do
      truncated = raw[0, i]
      break if truncated.bytesize <= byte_limit
      i-=1
    end

    opts.merge(:truncated => truncated)
  end

  # Truncates a string, so that it contains no more than 510 bytes.
  # We trim to 510 bytes, b/c the limit is 512, and we need to accommodate for cr/lf.
  def truncate_for_irc_server(raw)
    truncate_for_irc(raw, 510)
  end

  # This is like truncate_for_irc_server(),
  # but it also tries to compensate for truncation,
  # that will occur, if this command is broadcast to other clients.
  # On servers that support IDENTIFY-MSG, we also have to subtract 1,
  # because messages will have a + or - prepended,
  # when broadcast to clients that requested this capability.
  def truncate_for_irc_client(raw)
    limit = 510-@user.host_mask.bytesize-2
    limit -= 1 if @caps_listener.server_capabilities.include?(:'identify-msg')
    truncate_for_irc(raw, limit)
  end

  def send(raw)
    send_raw(truncate_for_irc_client(raw))
  end

  #returns number of characters written from given string
  def send_raw(raw)
    raw = truncate_for_irc_server(raw)

    @throttler.throttle do
      @last_sent = raw

      log_hide = raw[:log_hide]
      raw = raw[:truncated]
      log(:out, log_hide || raw)

      @sock.write "#{raw}\r\n"
    end

    raw.length
  end

  def receive(raw)
    @watch_time = Time.now

    raw = encode raw
    @last_received = raw

    log(:in, raw)

    dispatch(IRCMessage.new(self, raw.chomp))
  end

  def dispatch(msg)
    @router.dispatch_message(msg, @additional_listeners)
  end

  def start
    ContextMetadata.run_with(@config[:metadata]) do
      start_in_context
    end
  end

  def start_in_context
    @start_time = Time.now
    begin
      start_watchdog()

      server = @config[:server]
      if server.instance_of? Array
        # Try to connect to the given servers in order
        @last_failed_server = if @last_failed_server
                                (@last_failed_server + 1) % server.length
                              else
                                0
                              end
        server = server[@last_failed_server]
      end

      @sock = TCPSocket.open server, @config[:port]
      dispatch(OpenStruct.new({:command => :connection}))
      until @sock.eof? do # Throws Errno::ECONNRESET
        receive @sock.gets
        # improve latency a bit, by flushing output stream,
        # which was probably written into during the process
        # of handling received data
        @sock.flush
      end
    rescue SocketError, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
      log(:error, "Cannot connect: #{e}")
    rescue IOError => e
      log(:error, "IOError: #{e}")
    rescue SignalException => e
      raise e # Don't ignore signals
    rescue Exception => e
      log(:error, "Unexpected exception: #{e.inspect} #{e.backtrace.join(' ')}")
    ensure
      dispatch(OpenStruct.new({:command => :disconnection}))
      stop_watchdog()
      @sock = nil
    end
  end

  def stop
    if @sock
      log(:log, 'Forcibly closing socket')
      @sock.close
    end
  end

  def start_watchdog
    return if @watchdog
    if @config[:watchdog]
      @watch_time = Time.now
      @watchdog = Timer.new(30) do
        interval = @config[:watchdog]
        elapsed = Time.now - @watch_time
        if elapsed > interval
          log(:error, "Watchdog interval (#{interval}) elapsed, restarting bot")
          stop
        end
      end
    else
      @watchdog = nil
    end
  end

  def stop_watchdog
    return unless @watchdog
    @watchdog.stop
    @watchdog = nil
  end

  def join_channels(channels)
    send "JOIN #{channels*','}" if channels
  end

  def part_channels(channels)
    send "PART #{channels*','}" if channels
  end

  def find_user_by_nick(nick)
    @user_listener.findUserByNick(nick)
  end

  def find_user_by_uid(name)
    @user_listener.findUserByUID(name)
  end

  def find_user_by_msg(msg)
    @user_listener.findUser(msg)
  end

  def find_channel_by_msg(msg)
    @channel_pool.findChannel(msg)
  end

  def post_login
    # Successful connection.
    # Further reconnection attempts will try and start from
    # the beginning of the server list.
    @last_failed_server = nil

    #refresh our user info once,
    #so that truncate_for_irc_client()
    #will truncate messages properly
    @user_listener.request_whois(self, @user.nick)
    join_channels(@config[:channels])
  end

  private

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}IRC#{start_time.to_i}: #{Time.now}: #{text}"
  end

  # Checks to see if a string looks like valid UTF-8.
  # If not, it is re-encoded to UTF-8 from assumed CP1252.
  # This is to fix strings like "abcd\xE9f".
  def encode(str)
    str.force_encoding('UTF-8')
    unless str.valid_encoding?
      str.force_encoding('CP1252').encode!('UTF-8', {:invalid => :replace, :undef => :replace})
    end
    str
  end
end

=begin
# The IRC protocol requires that each raw message must be not longer
# than 512 characters. From this length with have to subtract the EOL
# terminators (CR+LF) and the length of ":botnick!botuser@bothost "
# that will be prepended by the server to all of our messages.

# The maximum raw message length we can send is therefore 512 - 2 - 2
# minus the length of our hostmask.

max_len = 508 - myself.fullform.size

# On servers that support IDENTIFY-MSG, we have to subtract 1, because messages
# will have a + or - prepended
if server.capabilities["identify-msg""identify-msg"]
  max_len -= 1
end

# When splitting the message, we'll be prefixing the following string:
# (e.g. "PRIVMSG #rbot :")
fixed = "#{type} #{where} :"

# And this is what's left
left = max_len - fixed.size
=end
