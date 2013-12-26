# encoding: utf-8

require_relative '../../IRCPlugin'

class Kanastats < IRCPlugin
  Description = "Counts all chars used in channels the bot is connected to as well as private messages."

  Dependencies = [ :StorageYAML ]

  Commands = {
    :hirastats => "Returns hiragana usage statistics.",
    :katastats => "Returns katakana usage statistics.",
    :charstats => "How often the specified char was used."
  }

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]
    @stats = @storage.read('kanastats') || {}
  end

  def beforeUnload
    @storage = nil
    @stats = nil
  end

  def store
    @storage.write('kanastats', @stats)
  end

  def on_privmsg(msg)
    case msg.botcommand
      when :hirastats
        output_hira(msg)
      when :katastats
        output_kata(msg)
      when :charstats
        charstat(msg)
      else
        statify(msg.message)
        store
    end
  end

  def statify(text)
    text.split("").each do |c|
      if !@stats[c]
        @stats[c] = 0
      end
      @stats[c] += 1
    end
  end

  def output_hira(msg)
    output_string = "Hiragana stats:"
    "あいうえおかきくけこさしすせそたちつてとなにぬねのまみむめもはひふへほやゆよらりるれろわゐゑをんばびぶべぼぱぴぷぺぽがぎぐげござじずぜぞだぢづでどゃゅょぁぃぅぇぉ".split("").each do |c|
      if !@stats[c]
        @stats[c] = 0
      end
      output_string << ' ' << c << @stats[c].to_s()
    end
    msg.reply output_string
  end

  def output_kata(msg)
    output_string = "Katakana stats:"
    "アイウエオカキクケコサシスセソタチツテトナニヌネノマミムメモハヒフヘホヤユヨラリルレロワヰヱヲンバビブベボパピプペポガギグゲゴザジズゼゾダヂヅデドャュョァィゥェォ".split("").each do |c|
      if !@stats[c]
        @stats[c] = 0
      end
      output_string << ' ' << c << @stats[c].to_s()
    end
    msg.reply output_string
  end

  def charstat(msg)
    output_string = "The char '"
    c = msg.tail[0]
    if !@stats[c]
      @stats[c] = 0
    end
    output_string << c
    if @stats[c] == 0
      output_string << "' wasn't used so far."
    elsif @stats[c] == 1
      output_string << "' was used once."
    else
      output_string << "' was used " << @stats[c].to_s() << " times."
    end
    msg.reply output_string
  end
end
