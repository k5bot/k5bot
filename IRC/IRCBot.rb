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
require_relative 'Timer'

class IRCBot < IRCListener
  attr_reader :router, :userPool, :channelPool, :pluginManager, :storage, :config, :last_sent, :last_received, :start_time, :user

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
    }

    @config.freeze  # Don't want anything modifying this

    @user = IRCUser.new(@config[:username], nil, @config[:realname], @config[:nickname])

    @router = IRCMessageRouter.new
    @router.register self

    @firstListener = IRCFirstListener.new # Set first listener
    @router.register @firstListener

    @pluginManager = IRCPluginManager.new(self, @config[:plugins]) # Add plugin manager

    @pluginManager.load_plugin(:StorageYAML)
    @storage = @pluginManager.plugins[:StorageYAML] # Add storage

    @userPool = IRCUserPool.new self  # Add user pool
    @router.register @userPool

    @channelPool = IRCChannelPool.new self  # Add channel pool
    @router.register @channelPool

    @pluginManager.load_all_plugins  # Load plugins

    $stdout.sync = true
  end

  def configure
    yield @config
  end

  #truncates truncates a string, so that it contains no more than byte_limit bytes
  #returns hash with key :truncated, containing resulting string.
  #hash is used to avoid double truncation and for future truncation customization.
  def truncate_for_irc(raw, byte_limit)
    return raw if (raw.instance_of? Hash) #already truncated
    raw = encode raw.dup

    #char-per-char correspondence replace, to make the returned count meaningful
    raw.gsub!("\n", ' ')
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

    {:truncated => truncated}
  end

  #truncates truncates a string, so that it contains no more than 510 bytes
  #we trim to 510 bytes, b/c the limit is 512, and we need to accommodate for cr/lf
  def truncate_for_irc_server(raw)
    truncate_for_irc(raw, 510)
  end

  #this is like truncate_for_irc_server(),
  #but it also tries to compensate for truncation, that
  #will occur, if this command is broadcast to other clients.
  def truncate_for_irc_client(raw)
    truncate_for_irc(raw, 510-@user.host_mask.bytesize-2)
  end

  def send(raw)
    send_raw(truncate_for_irc_client(raw))
  end

  #returns number of characters written from given string
  def send_raw(raw)
    raw = truncate_for_irc_server(raw)

    @last_sent = raw
    raw = raw[:truncated]
    log_sent_message(raw)

    @sock.write "#{raw}\r\n"

    raw.length
  end

  def log_sent_message(raw)
    str = raw.dup
    str.gsub!(@config[:serverpass], '*SRP*') if @config[:serverpass]
    str.gsub!(@config[:userpass], '*USP*') if @config[:userpass]
    puts "#{timestamp} \e[#34m#{str}\e[0m"
  end


  def receive(raw)
    @watch_time = Time.now

    raw = encode raw
    @last_received = raw
    puts "#{timestamp} #{raw}"
    @router.receive_message IRCMessage.new(self, raw.chomp)
  end

  def timestamp
    "\e[#37m#{Time.now}\e[0m"
  end

  def start
    @start_time = Time.now
    begin
      if @config[:watchdog]
        @watch_time = @start_time
        @watchdog = Timer.new(30) do
          interval = @config[:watchdog]
          elapsed = Time.now - @watch_time
          if elapsed > interval
            puts "#{timestamp} Watchdog interval (#{interval}) elapsed, restarting bot"
            self.stop
            stop
          end
        end
      else
        @watchdog = nil
      end

      @sock = TCPSocket.open @config[:server], @config[:port]
      login
      until @sock.eof? do # Throws Errno::ECONNRESET
        receive @sock.gets
      end
    rescue SocketError, Errno::ECONNRESET => e
      puts "Cannot connect: #{e}"
    rescue IOError => e
      puts "IOError: #{e}"
    ensure
        if @watchdog
          @watchdog.stop
          @watchdog = nil
        end
      @sock = nil
    end
  end

  def stop
    if @sock
      puts "Forcibly closing socket"
      @sock.close
    end
  end

  def on_notice(msg)
    if msg.message && (msg.message =~ /^You are now identified for .*#{@config[:username]}.*\.$/)
      post_login
    end
  end

  def join_channels(channels)
    send "JOIN #{channels*','}" if channels
  end

  def part_channels(channels)
    send "PART #{channels*','}" if channels
  end

  private
  def login
    send "PASS #{@config[:serverpass]}" if @config[:serverpass]
    send "NICK #{@config[:nickname]}" if @config[:nickname]
    send "USER #{@config[:username]} 0 * :#{@config[:realname]}" if @config[:username] && @config[:realname]
    if @config[:userpass]
      send "PRIVMSG NickServ :IDENTIFY #{@config[:username]} #{@config[:userpass]}"
    else
      post_login
    end
  end

  def post_login
    #refresh our user info once,
    #so that truncate_for_irc_client()
    #will truncate messages properly
    @userPool.request_whois(@user.nick)
    join_channels(@config[:channels])
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
