# encoding: utf-8

require 'fileutils'

require_relative '../../IRCPlugin'
require_relative '../../LayoutableText'

class Kanastats < IRCPlugin
  Description = "Statistics plugin logging all public conversation and \
providing tools to analyze it."

  Dependencies = [ :StorageYAML ]

  Commands = {
    :hirastats => 'Returns hiragana usage statistics.',
    :katastats => 'Returns katakana usage statistics.',
    :charstats => 'How often the specified char was publicly used.',
    :wordstats => 'How often the specified word or character was used in logged public conversation.',
    :logged    => 'Displays information about the log files.',
    :wordfight! => 'Compares count of words in logged public conversation.',
    :cjkstats => 'Counts number of all CJK characters ever written in public conversation. Also outputs the top 10 CJK characters, or top n to n+10 if a number is provided, e.g. .cjkstats 20.',
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
        output_group_stats(msg, 'Hiragana stats: ', ALL_HIRAGANA)
      when :katastats
        output_group_stats(msg, 'Katakana stats: ', ALL_KATAKANA)
      when :charstats
        charstat(msg)
      when :wordstats
        wordstats(msg)
      when :logged
        logged(msg)
      when :wordfight!
        wordfight(msg)
      when :cjkstats
        cjkstats(msg)
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

  ALL_HIRAGANA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのまみむめもはひふへほやゆよらりるれろわゐゑをんばびぶべぼぱぴぷぺぽがぎぐげござじずぜぞだぢづでどゃゅょぁぃぅぇぉっ'
  ALL_KATAKANA = 'アイウエオカキクケコサシスセソタチツテトナニヌネノマミムメモハヒフヘホヤユヨラリルレロワヰヱヲンバビブベボパピプペポガギグゲゴザジズゼゾダヂヅデドャュョァィゥェォッ'

  def output_group_stats(msg, prefix, symbols_array)
    output_array = symbols_array.each_char.sort_by do |c|
      -@stats[c] || 0
    end.map do |c|
      "#{c} #{@stats[c] || 0}"
    end.to_a

    msg.reply(
        LayoutableText::Prefixed.new(
            prefix,
            LayoutableText::SimpleJoined.new(' ', output_array)
        )
    )
  end

  def contains_cjk?(s)
    !!(s =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)
  end

  def cjkstats(msg)
    number = 0
    number = msg.tail.split(" ")[0].to_i || 0 if msg.tail
    cjk_count = 0
    non_count = 0
    cjk_individual = 0
    @stats.each do |c, v|
      if contains_cjk?(c)
        cjk_count += v
        cjk_individual +=1 unless (ALL_HIRAGANA.include?(c) or ALL_KATAKANA.include?(c))
      else
        non_count += v
      end
    end

    number = [(cjk_individual-11), number].min

    top10 = @stats.sort_by do |c,v|
      if contains_cjk?(c) and not ALL_HIRAGANA.include?(c) and not ALL_KATAKANA.include?(c)
        v
      else
        0
      end
    end.reverse[number..(number+10)].to_a

    msg.reply("#{cjk_count} CJK characters and #{non_count} non-CJK characters were written.")
    msg.reply(
        LayoutableText::Prefixed.new(
            "Top #{number+1} to #{number+11} non-kana CJK characters: ",
            LayoutableText::SimpleJoined.new(' ', top10)
        )
    )
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

    count = count_logfile( word )

    msg.reply("The word '#{word}' #{used_text(count)}.")
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

  RANDOM_FUNNY_REPLIES = [
      'Kanastats online and fully operational.',
      'Kanastats is watching you.',
  ]

  def logged(msg)
    count = File.foreach(@log_file).count
    msg.reply(
        "#{RANDOM_FUNNY_REPLIES.sample} Currently #{count} lines and #{@stats.size} different characters have been logged."
    )
  end

  def count_logfile(word)
    count = File.open(@log_file) do |f|
      f.each_line.map { |l| l.scan(word).size }.inject(0, :+)
    end
    return count
  end

  def wordfight(msg)
    words = msg.tail.gsub(/　/, " ").split(" ")
    return unless words.length >= 1

    word_counts = Hash.new
    words.each{ |w| word_counts[w] = count_logfile(w) }

    word_counts=Hash[ word_counts.sort_by{ |a,b| b }.reverse! ]

    output_string = ""

    word_counts.each_with_index do |(w,c),i|
      output_string += "#{w}(#{c})"
      if ( i+1 < word_counts.length && c > word_counts.values[i+1] )
        output_string += " ＞ "
      elsif i+1 < word_counts.length
        output_string += " ＝ "
      end
    end

    msg.reply output_string
  end
end
