# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client chat worker

require 'ipaddr'
require 'socket'
require 'ostruct'

require_relative '../../IRCPlugin'

class DCCBot
  attr_reader :last_sent, :last_received, :start_time, :caller_id
  attr_accessor :credentials, :authorities

  def initialize(socket, dcc_plugin, parent_bot)
    @socket = socket
    @dcc_plugin = dcc_plugin
    @parent_bot = parent_bot

    @last_sent = nil
    @last_received = nil
    @start_time = Time.now

    # [host, ip] or [ip], if reverse resolution failed
    @caller_id = @socket.peeraddr(true)[2..-1].uniq

    @credentials = @authorities = nil

    log(:log, "Got incoming connection from #{@caller_id.join(' ')}")
  end

  def user
    @parent_bot.user
  end

  def find_user_by_msg(msg)
    @parent_bot.find_user_by_msg(msg)
  end

  def find_user_by_nick(nick)
    @parent_bot.find_user_by_nick(nick)
  end

  def find_user_by_uid(name)
    @parent_bot.find_user_by_uid(name)
  end

  def start
    log(:log, 'Starting interaction.')

    @listen_thread = Thread.start(self) do |dcc_bot|
      begin
        dcc_bot.dcc_send("Hello! You're authorized as: #{authorities.join(' ')}; Credentials: #{credentials.join(' ')}")
        @socket.flush

        #until @socket.eof? do # for some reason blocks until user sends several lines.
        loop do
          dcc_bot.receive(@socket.gets)
          # improve latency a bit, by flushing output stream,
          # which was probably written into during the process
          # of handling received data
          @socket.flush
        end
      ensure
        dcc_bot.close
      end
    end
  end

  def is_dead?
    @socket.closed? rescue true # assume the worst
  end

  def close
    log(:log, 'Terminating connection.')

    @socket.close rescue nil
    (@listen_thread.join unless Thread.current.eql?(@listen_thread)) rescue nil
  end

  def receive(raw)
    @watch_time = Time.now

    raw = encode raw
    @last_received = raw

    log(:in, raw)

    begin
      @dcc_plugin.dispatch(DCCMessage.new(self, raw.chomp, @authorities.first))
    rescue Exception => e
      log(:error, e.inspect)
    end
  end

  def dcc_send(raw)
    if raw.instance_of?(Hash)
      return raw if raw[:truncated] #already truncated
      #opts = raw
      raw = raw[:original]
    else
      #opts = {:original => raw}
    end
    raw = encode raw.dup

    #char-per-char correspondence replace, to make the returned count meaningful
    raw.gsub!(/[\r\n]/, ' ')
    raw.strip!

    @last_sent = raw

    log(:out, raw)

    @socket.write "#{raw}\r\n"
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}DCC#{start_time.to_i}: #{Time.now}: #{text}"
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
