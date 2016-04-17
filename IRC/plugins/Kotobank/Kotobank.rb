require_relative '../../IRCPlugin'

class Kotobank < IRCPlugin
  DESCRIPTION = 'Returns link to kotobank.jp/weblio.jp/kobun.weblio.jp lookup.'
  Commands = {
    :du => "returns kotobank link",
    :wl => "returns weblio link",
    :wk => "returns kobun.weblio link"
  }

  def on_privmsg(msg)
    case msg.botcommand
      when :du
        msg.reply Addressable::URI.encode( "http://kotobank.jp/word/#{msg.tail}?dic=daijirin" )
      when :wl
        msg.reply Addressable::URI.encode( "http://www.weblio.jp/content/#{msg.tail}" )
      when :wk
        msg.reply Addressable::URI.encode( "http://kobun.weblio.jp/content/#{msg.tail}" )
    end
  end
end
