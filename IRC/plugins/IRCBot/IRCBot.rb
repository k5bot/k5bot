# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCBot

require 'socket'
require 'ostruct'

require_relative '../../Emitter'
require_relative '../../Throttler'
require_relative '../../IRCPlugin'
require_relative '../../LayoutableText'
require_relative '../../ContextMetadata'

require_relative 'IRCUser'
require_relative 'IRCMessage'
require_relative 'IRCLoginListener'
require_relative 'IRCFirstListener'

class IRCBot < IRCPlugin
  include BotCore::Emitter

  Description = 'Provides IRC connectivity.'

  Dependencies = [ :Connectix, :Router, :StorageYAML ]

  attr_reader :last_sent, :start_time, :user

  DEFAULT_SERVER = 'localhost'
  DEFAULT_PORT = 6667

  def afterLoad
    load_helper_class(:IRCUser)
    load_helper_class(:IRCChannel)
    load_helper_class(:IRCMessage)
    load_helper_class(:IRCCapsListener)
    load_helper_class(:IRCServerPassListener)
    load_helper_class(:IRCUserListener)
    load_helper_class(:IRCChannelListener)
    load_helper_class(:IRCLoginListener)
    load_helper_class(:IRCIdentifyListener)
    load_helper_class(:IRCModeListener)
    load_helper_class(:IRCJoinListener)
    load_helper_class(:IRCFirstListener)

    @config = {
      :serverpass => nil,
      :username => 'bot',
      :nickname => 'bot',
      :realname => 'Bot',
      :channels => nil,
      :plugins  => nil,
    }.merge!(@config)

    @config.freeze  # Don't want anything modifying this

    raise ':connector: key is not specified in config' unless @config[:connector]

    @throttler = Throttler.new(@config[:burst] || 0, @config[:rate] || 0)

    @user = IRCUser.new(@config[:username], nil, @config[:realname], @config[:nickname])

    @caps_listener = IRCCapsListener.new(self)
    @server_pass_listener = IRCServerPassListener.new(self, @config[:serverpass])
    @user_listener = IRCUserListener.new(@plugin_manager.plugins[:StorageYAML])
    @channel_listener = IRCChannelListener.new
    @login_listener = IRCLoginListener.new(self, @config)
    @identify_listener = IRCIdentifyListener.new(self, @config[:identify])
    @mode_listener = IRCModeListener.new(self, @config[:mode])
    @join_listener = IRCJoinListener.new(self, @config[:channels])
    @first_listener = IRCFirstListener.new

    @additional_listeners = [
        @caps_listener,
        @server_pass_listener,
        @user_listener,
        @channel_listener,
        @login_listener,
        @identify_listener,
        @mode_listener,
        @join_listener,
        @first_listener,
    ]

    @connectix = @plugin_manager.plugins[:Connectix]
    @router = @plugin_manager.plugins[:Router] # Get router

    @thread = nil

    start
  end

  def beforeUnload
    stop(true)

    @thread = nil

    @router = nil
    @connectix = nil

    @first_listener = nil
    @join_listener = nil
    @mode_listener = nil
    @identify_listener = nil
    @login_listener = nil
    @channel_listener = nil
    @user_listener = nil
    @server_pass_listener = nil
    @caps_listener = nil

    @user = nil

    @throttler = nil

    unload_helper_class(:IRCFirstListener)
    unload_helper_class(:IRCJoinListener)
    unload_helper_class(:IRCModeListener)
    unload_helper_class(:IRCIdentifyListener)
    unload_helper_class(:IRCLoginListener)
    unload_helper_class(:IRCChannelListener)
    unload_helper_class(:IRCUserListener)
    unload_helper_class(:IRCServerPassListener)
    unload_helper_class(:IRCCapsListener)
    unload_helper_class(:IRCMessage)
    unload_helper_class(:IRCChannel)
    unload_helper_class(:IRCUser)

    nil
  end

  # Lays out strings from given LayoutableText, so that every line contains
  # no more than byte_limit bytes. Returns opts hash with key :truncated
  # mapped to the array of resulting lines.
  def truncate_for_irc(opts, byte_limit)
    layoutable_text = opts[:original]

    layout = layout_to_byte_limit(layoutable_text, byte_limit, !opts[:dont_truncate])

    layout = layout.map do |line|
      if line.bytesize > byte_limit
        # Lines were allowed to overflow, so truncate to fit byte limit
        line = layout_to_byte_limit(
            LayoutableText::Arrayed.new(line, 1),
            byte_limit,
            false
        ).first
      end

      line
    end

    opts.merge(:truncated => layout)
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

  def irc_send(text, opts = {})
    do_send_raw(truncate_for_irc_client(opts.merge(:original => text)))
  end

  def send_raw(opts)
    unless opts.is_a?(Hash)
      opts = {:original => opts}
    end
    text = opts[:original]
    unless text.is_a?(LayoutableText)
      return unless text
      text = text.to_s
      return if text.empty?
      opts[:original] = LayoutableText::SingleString.new(text)
    end
    do_send_raw(truncate_for_irc_server(opts))
  end

  def do_send_raw(opts)
    log_hide = opts[:log_hide]
    layout = opts[:truncated]
    layout.each do |raw|
      @throttler.throttle do
        log(:out, log_hide || raw)
        @last_sent = raw
        @sock.write "#{raw}\r\n"
      end
    end
  end

  def receive(raw)
    raw = encode raw

    log(:in, raw)

    dispatch(IRCMessage.new(self, raw.chomp))
  end

  def dispatch(msg)
    @router.dispatch_message(msg, @additional_listeners)
  end

  def start
    return if @thread

    @thread = Thread.new do
      ContextMetadata.run_with(@config[:metadata]) do
        @terminate = false

        until @terminate do
          start_in_context
          # wait a bit before reconnecting
          sleep(@config[:reconnect_delay] || 15) unless @terminate
        end
      end
    end
  end

  def stop(permanently = false)
    thread = @thread
    return unless thread

    if permanently
      @terminate = true
      stop_in_context rescue nil
      thread.join unless Thread.current.eql?(thread)
      @thread = nil
    else
      stop_in_context
    end
  end

  def start_in_context
    @start_time = Time.now
    @sock = nil
    begin
      @sock = @connectix.connectix_open(
          @config[:connector],
          Connectix::ConnectorTCP::DEFAULT_HOST_KEY => DEFAULT_SERVER,
          Connectix::ConnectorTCP::DEFAULT_PORT_KEY => DEFAULT_PORT,
      )
      return if @terminate
      begin
        dispatch(OpenStruct.new({:command => :connection}))
        until @sock.eof? do # Throws Errno::ECONNRESET
          receive @sock.gets
          # improve latency a bit, by flushing output stream,
          # which was probably written into during the process
          # of handling received data
          @sock.flush
        end
      ensure
        dispatch(OpenStruct.new({:command => :disconnection}))
      end
    rescue SocketError, Errno::ECONNRESET, Errno::EHOSTUNREACH => e
      log(:error, "Cannot connect: #{e}")
    rescue IOError => e
      log(:error, "IOError: #{e}")
    rescue Exception => e
      log(:error, "Unexpected exception: #{e.inspect} #{e.backtrace.join(' ')}")
    ensure
      @sock.close rescue nil
      @sock = nil
    end
  end

  def stop_in_context
    if @sock
      log(:log, 'Forcibly closing socket')
      @sock.close
    end
  end

  def join_channels(channels)
    send_raw(
        LayoutableText::Prefixed.new(
            'JOIN ',
            LayoutableText::SimpleJoined.new(',', channels)
        )
    ) if channels
  end

  def part_channels(channels)
    send_raw(
        LayoutableText::Prefixed.new(
            'PART ',
            LayoutableText::SimpleJoined.new(',', channels)
        )
    ) if channels
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
    @channel_listener.findChannel(msg)
  end

  def post_login
    # Hint Connectix about successful connection, if applicable.
    @sock.connectix_logical_success if @sock.respond_to?(:connectix_logical_success)

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

  def layout_to_byte_limit(layoutable_text, byte_limit, allow_overflow)
    layout = layoutable_text.layout_calculate do |line, minimum_size: false, ** _|
    line = encode(line.dup)

    # char-per-char replace
    line.gsub!(/[\r\n]/, ' ')
    # whitespace elimination
    line.strip!

    # Accept line if it fits in the byte limit. Also accept if if it doesn't
    # fit, but is still the smallest line that our layouter can produce.
    # Except if our caller insisted on not truncating lines, in which case
    # layouter will raise an exception due to not finding a satisfactory layout.
    line if (line.bytesize <= byte_limit) || (minimum_size && allow_overflow)
    end
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
