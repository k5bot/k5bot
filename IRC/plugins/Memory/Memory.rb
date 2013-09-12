require_relative '../../IRCPlugin'

class Memory < IRCPlugin
  Description = "Monitors memory useage."
  Commands = {
    :free => "returns free memory"
  }

  def on_privmsg(msg)
    case msg.botcommand
      when :free
        free_array = `free`.split(" ")
        mfree = free_array[8].to_i
        mtotal = free_array[7].to_i
        sfree = free_array[19].to_i
        stotal = free_array[18].to_i
        msg.reply "Memory usage: #{'%.2f' % (mfree / 1024)} of #{'%.2f' % (mtotal / 1024)} MiB \/\/ SWAP usage: #{'%.2f' % (sfree / 1024)} of #{'%.2f' % (stotal / 1024)} MiB"
    end
  end
end
