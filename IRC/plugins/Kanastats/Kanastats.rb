# encoding: utf-8

require_relative '../../IRCPlugin'

require 'fileutils'

class Kanastats < IRCPlugin
  Description = "Statistics plugin logging all public conversation and \
providing tools to analyze it."

  Dependencies = [ :StorageYAML ]

  Commands = {
    :hirastats => 'Returns hiragana usage statistics.',
    :katastats => 'Returns katakana usage statistics.',
    :charstats => 'How often the specified char was publicly used.',
    :wordstats => 'How often the specified word was publicly used.',
    :logged    => 'Displays information about the log files.',
  }

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @stats = @storage.read('kanastats') || {}

    dir = @config[:data_directory]
    dir ||= @storage.config[:data_directory]
    dir ||= '~/.ircbot'

    @data_directory = File.expand_path(dir).chomp('/')
    @log_file = "#{@data_directory}/public_logfile"
  end

  def beforeUnload
    @log_file = nil
    @data_directory = nil
    @stats = nil
    @storage = nil

    nil
  end

  def store
    @storage.write('kanastats', @stats)
  end

  def on_privmsg(msg)
    case msg.bot_command
      when :hirastats
        output_hira(msg)
      when :katastats
        output_kata(msg)
      when :charstats
        charstat(msg)
      when :wordstats
        wordstats(msg)
      when :logged
        logged(msg)
      else
        unless msg.private?
          statify(msg.message)
          log(msg.message)
        end
    end
  end

  def statify(text)
    return unless text
    text.each_char do |c|
      @stats[c] ||= 0
      @stats[c] += 1
    end
    store
  end

  ALL_HIRAGANA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのまみむめもはひふへほやゆよらりるれろわゐゑをんばびぶべぼぱぴぷぺぽがぎぐげござじずぜぞだぢづでどゃゅょぁぃぅぇぉ'
  ALL_KATAKANA = 'アイウエオカキクケコサシスセソタチツテトナニヌネノマミムメモハヒフヘホヤユヨラリルレロワヰヱヲンバビブベボパピプペポガギグゲゴザジズゼゾダヂヅデドャュョァィゥェォ'

  def output_hira(msg)
    output_array = ALL_HIRAGANA.each_char.map do |c|
      "#{c} #{@stats[c] || 0}"
    end.to_a

    reply_untruncated(msg, output_array) do |chunk|
      "Hiragana stats: #{chunk.join(' ')}"
    end
  end

  def output_kata(msg)
    output_array = ALL_KATAKANA.each_char.map do |c|
      "#{c} #{@stats[c] || 0}"
    end.to_a

    reply_untruncated(msg, output_array) do |chunk|
      "Katakana stats: #{chunk.join(' ')}"
    end
  end

  def charstat(msg)
    word = msg.tail
    return unless word

    c = word[0]
    count = @stats[c] || 0

    msg.reply("The char '#{c}' #{used_text(count)}.")
  end

  def log(line)
    return unless line
    File.open(@log_file, 'a') { |f| f.write(line + "\n") }
  end

  def wordstats(msg)
    word = msg.tail
    return unless word

    count = File.open(@log_file) do |f|
      f.each_line.map { |l| l.scan(word).size }.inject(0, :+)
    end

    msg.reply("The word '#{word}' #{used_text(count)}.")
  end

  def reply_untruncated(msg, output_array)
    until output_array.empty?
      chunk_size = output_array.size
      begin
        output_string = yield(output_array[0..chunk_size-1])
        msg.reply(output_string, :dont_truncate => (chunk_size > 1))
      rescue
        chunk_size -= 1
        retry if chunk_size > 0
      end
      output_array.slice!(0, chunk_size)
    end
  end

  def used_text(count)
    case count
      when 0
        "wasn't used so far"
      when 1
        'was used once'
      else
        "was used #{count} times"
    end
  end

  def logged(msg)
    count = File.foreach(@log_file).count
    msg.reply "Kanastats online and fully operational. Currently #{count} lines and #{@stats.size} chars have been logged."
  end
end
