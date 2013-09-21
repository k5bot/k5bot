# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# HTTP Servlet for serving main page and converting user input to WebMessage-s

require_relative '../../Emitter'

class WebBotServlet < WEBrick::HTTPServlet::AbstractServlet
  include BotCore::Emitter

  attr_reader :server
  attr_accessor :user_auth

  def initialize(server, plugin_instance, parent_bot)
    super

    @plugin_instance = plugin_instance
    @parent_bot = parent_bot

    @user_auth = nil
  end

  def start_time
    @plugin_instance.start_time
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

  #noinspection RubyInstanceMethodNamingConvention
  def do_POST(request, response)
    @user_auth = request.user

    reply_array = []
    ContextMetadata.run_with(
        :web_server_response => reply_array,
        :web_session => request.query['session'].to_s) do
      message = request.query['query'].to_s
      receive(message)
    end

    response.status = 200
    response['Content-Type'] = 'text/plain; charset=utf-8'
    response.body = reply_array.join("\n")
  end

  def receive(raw)
    @watch_time = Time.now

    raw = encode raw

    do_log(:in, raw)

    begin
      @plugin_instance.dispatch(
          WebMessage.new(self,
                         raw.chomp,
                         @user_auth.principals.first,
                         ContextMetadata.get_key(:web_session),
          )
      )
    rescue Exception => e
      do_log(:error, "#{e.inspect} #{e.backtrace.join("\n")}")
    end
  end

  def web_send(raw)
    response_array = ContextMetadata.get_key(:web_server_response)
    return unless response_array.instance_of?(Array)

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

    do_log(:out, raw)

    #@socket.write "#{raw}\r\n"
    response_array << raw
  end

  # Stub to avoid hanging on unknown method
  def send_raw(raw)
    raise "Can't send_raw() in WebBot! Raw: #{raw}"
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def do_log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}#{self.class.name}: #{Time.now}: #{text}"
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
