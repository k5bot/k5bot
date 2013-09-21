# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Plugin for accepting input from console.

require_relative '../../Emitter'
require_relative '../../IRCPlugin'

class Console < IRCPlugin
  include BotCore::Emitter

  Description = 'Console interaction plugin'
  Dependencies = [ :Router ]

  attr_reader :start_time

  def afterLoad
    load_helper_class(:ConsoleUser)
    load_helper_class(:ConsoleMessage)

    @router = @plugin_manager.plugins[:Router]
    @start_time = Time.now
    @stream_in = $stdin
    @stream_out = $stdout
  end

  def beforeUnload
    @stream_out = nil
    @stream_in = nil
    @start_time = nil
    @router = nil

    unload_helper_class(:ConsoleMessage)
    unload_helper_class(:ConsoleUser)

    nil
  end

  def dispatch(msg)
    @router.dispatch_message(msg)
  end

  def user
    ConsoleUser.instance
  end

  def find_user_by_msg(msg)
    return msg.bot.find_user_by_msg(msg) unless msg.bot == self
    ConsoleUser.instance
  end

  def find_user_by_nick(nick)
    ConsoleUser.instance if ConsoleUser.instance.nick.eql?(nick)
  end

  def find_user_by_uid(uid)
    ConsoleUser.instance if ConsoleUser.instance.uid.eql?(uid)
  end

  def serve
    log(:log, 'Starting console interaction')

    begin
      while @stream_in && (raw = @stream_in.gets) do
        self.receive(raw)
      end
    ensure
      log(:log, 'Stopping console interaction')
    end
  end

  def stop
    @stream_in = nil
  end

  def receive(raw)
    raw = encode raw

    log(:in, raw)

    begin
      dispatch(ConsoleMessage.new(self, raw.chomp))
    rescue Exception => e
      log(:error, "#{e.inspect} #{e.backtrace.join("\n")}")
    end
  end

  def console_send(raw)
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
    raw.rstrip!

    log(:out, raw)

    @stream_out.puts raw if @stream_out
  end

  # Stub to avoid hanging on unknown method
  def send_raw(raw)
    raise "Can't send_raw() in Console! Raw: #{raw}"
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def log(mode, text)
    return if mode == :in && @stream_in.eql?($stdin)
    return if mode == :out && @stream_out.eql?($stdout)
    puts "#{TIMESTAMP_MODE[mode]}Console: #{Time.now}: #{text}"
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
