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

    @allowed_to_reply = true
  end

  def beforeUnload
    @l = nil

    nil
  end

  def on_privmsg(msg)
    raw_message = msg.message
    nick_stripped = raw_message.gsub(/^\s*#{msg.bot.user.nick}\s*[:>,]?\s+/, '')

    # Respond only to "bot_nick: greeting", if 'channel_name: true' is specified in config.
    if config[msg.channelname] && raw_message.eql?(nick_stripped)
      @allowed_to_reply = true
      return
    end

    tail = nick_stripped.gsub(/[\s!?！？〜\.。]/, '').strip
    tail_kana = @l.hiragana(@l.kana(tail))

    reply_index = Hello.find_index do |i|
      @l.hiragana(i) == tail_kana
    end

    msg.reply(self.class::Hello[reply_index]) if @allowed_to_reply && reply_index

    @allowed_to_reply = reply_index.nil?
  end
end
