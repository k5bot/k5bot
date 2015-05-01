require_relative '../../IRCPlugin'

class Memory < IRCPlugin
  Description = 'Monitors memory usage.'
  Commands = {
    :free => 'reports memory info'
  }

  def on_privmsg(msg)
    case msg.botcommand
      when :free
        d = File.open('/proc/meminfo') do |f|
          Hash[f.each_line.map do |l|
            key, value = l.split()
            [key.downcase.delete(':').to_sym, value.to_i]
          end]
        end

        # Thanks to CalimeroTeknik for this memory calculation formula
        mused = d[:memtotal] - d[:memfree] - d[:cached] - d[:buffers] + d[:shmem] + d[:slab] + d[:kernelstack] + d[:pagetables]
        mtotal = d[:memtotal]

        stotal = d[:swaptotal]
        sused = stotal - d[:swapfree]

        msg.reply "Memory usage: #{'%.2f' % (mused / 1024)} of #{'%.2f' % (mtotal / 1024)} MiB \/\/ SWAP usage: #{'%.2f' % (sused / 1024)} of #{'%.2f' % (stotal / 1024)} MiB"
    end
  end
end
