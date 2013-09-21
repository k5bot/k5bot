require_relative '../../IRCPlugin'

class Memory < IRCPlugin
  Description = "Bot memory usage."
  Commands = {
    :memory => "returns bot memory usage"
  }

  def on_privmsg(msg)
    case msg.bot_command
      when :memory
        pid, size = `ps ax -o pid,rss | grep -E "^[[:space:]]*#{$$}"`.strip.split.map(&:to_i)
        msg.reply "Bot currently uses #{'%.2f' % (size / 1024)} MiB of memory!"
    end
  end
end
