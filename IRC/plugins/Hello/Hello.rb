# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Hello plugin

class Hello < IRCPlugin
  Description = "Says hello."
  Dependencies = [ :Language ]

  Hello = [
    'おはよう',
    'おはようございます',
    'こんにちは',
    'こんばんは',
    'さようなら',
    'おやすみ',
    'おやすみなさい',
    'もしもし',
    'やっほー',
    'ハロー',
    'ごきげんよう',
    'どうも',
  ]

  def afterLoad
    @l = plugin_manager.plugins[:Language]

    @forbidden_to_reply = {}
  end

  def beforeUnload
    @l = nil

    nil
  end

  def on_privmsg(msg)
    raw_message = msg.message
    nick_stripped = raw_message.gsub(/^\s*#{msg.bot.user.nick}\s*[:>,]?\s+/, '')

    channel_name = msg.channelname

    # Respond only to "bot_nick: greeting", if 'channel_name: true' is specified in config.
    if config[channel_name] && raw_message.eql?(nick_stripped)
      @forbidden_to_reply.delete(channel_name)
      return
    end

    tail = nick_stripped.gsub(/[\s!?！？〜\.。]/, '').strip
    tail_kana = @l.hiragana(@l.romaji_to_hiragana(tail))

    reply_index = Hello.find_index do |i|
      @l.hiragana(i) == tail_kana
    end

    if reply_index
      unless @forbidden_to_reply[channel_name]
        msg.reply(self.class::Hello[reply_index])
        @forbidden_to_reply[channel_name] = true
      end
    else
      @forbidden_to_reply.delete(channel_name)
    end
  end
end
