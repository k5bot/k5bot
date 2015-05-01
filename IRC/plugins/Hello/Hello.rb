# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Hello plugin

class Hello < IRCPlugin
  Description = 'Says hello.'
  Dependencies = [ :Language ]

  GREETINGS = %w(
おはよう
おはようございます
こんにちは
こんばんは
さようなら
おやすみ
おやすみなさい
もしもし
やっほー
ハロー
ごきげんよう
どうも
)

  TIMEOUT = 600

  def afterLoad
    @l = plugin_manager.plugins[:Language]

    @forbidden_to_reply = {}
  end

  def beforeUnload
    @l = nil

    nil
  end

  def on_privmsg(msg)
    tail = msg.tail
    return unless tail

    channel_name = msg.channelname

    tail = tail.gsub(/[\s!?！？〜\.。]/, '')
    tail_kana = @l.katakana_to_hiragana(@l.romaji_to_hiragana(tail))

    response = GREETINGS.find do |greeting|
      @l.katakana_to_hiragana(greeting) == tail_kana
    end

    if response
      last_time = @forbidden_to_reply[channel_name]
      current_time = Time.now.to_i
      if !last_time || (last_time + TIMEOUT) < current_time
        msg.reply(response)
        @forbidden_to_reply[channel_name] = current_time
      end
    else
      @forbidden_to_reply.delete(channel_name)
    end
  end
end
