# encoding: utf-8

require 'fileutils'

require 'IRC/IRCPlugin'
require 'IRC/LayoutableText'

class Kanastats
  include IRCPlugin
  DESCRIPTION = "Statistics plugin logging all public conversation and \
providing tools to analyze it."

  DEPENDENCIES = [:StorageYAML]

  COMMANDS = {
    :hirastats => 'Returns hiragana usage statistics.',
    :katastats => 'Returns katakana usage statistics.',
    :charstats => 'How often the specified char was publicly used.',
    :wordstats => 'How often the specified word or character was used in logged public conversation.',
    :logged    => 'Displays information about the log files.',
    # Let's not pollute help with this for now.
    #:wordcount! => 'Same as .wordfight! but outputs words in the same order as given.',
    :wordfight! => 'Compares count of words in logged public conversation.',
    :cjkstats => 'Counts number of all CJK characters ever written in public conversation. Also outputs the top 10 non-Kana CJK characters, or top n to n+9 if a number is provided, e.g. .cjkstats 20. And if you write a kanji, it will show the list surrounding that one.',
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
      when :wordcount!
        wordfight(msg, sort = false)
      when :wordfight!
        wordfight(msg, sort = true)
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

  ALL_HIRAGANA = 'あいうゔえおかきくけこさしすせそたちつてとなにぬねのまみむめもはひふへほやゆよらりるれろわゐゑをんばびぶべぼぱぴぷぺぽがぎぐげござじずぜぞだぢづでどゃゅょぁぃぅぇぉっ'
  ALL_KATAKANA = 'アイウヴエオカキクケコサシスセソタチツテトナニヌネノマミムメモハヒフヘホヤユヨラリルレロワヰヱヲンバビブベボパピプペポガギグゲゴザジズゼゾダヂヅデドャュョァィゥェォッ'
  ALL_HALFWIDTH = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾏﾐﾑﾒﾓﾊﾋﾌﾍﾎﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ'

  def output_group_stats(msg, prefix, symbols_array)
    output_array = symbols_array.each_char.sort_by do |c|
      -(@stats[c] || 0)
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

    counts = @stats.group_by do |c, _|
      if contains_cjk?(c)
        if ALL_HIRAGANA.include?(c) || ALL_KATAKANA.include?(c) || ALL_HALFWIDTH.include?(c)
          :kana
        else
          :cjk
        end
      else
        :non_cjk
      end
    end

    top10 = counts[:cjk].sort_by {|_, v| -v}

    if msg.tail
      arg = msg.tail.split.first
      arg_char = arg[0]
      if contains_cjk?(arg_char)
        number = (top10.index([arg_char, @stats[arg_char]]) || 0) - 5
      else
        number = (arg.to_i - 1) || 0
      end
    end

    number = [0, [number, top10.size - 10].min].max
    top10 = top10[number, 10]

    cjk_count = counts[:cjk].map(&:last).inject(0, &:+)
    cjk_count += counts[:kana].map(&:last).inject(0, &:+)
    non_count = counts[:non_cjk].map(&:last).inject(0, &:+)

    msg.reply("#{cjk_count} CJK characters and #{non_count} non-CJK characters were written.") unless msg.tail
    msg.reply(
        LayoutableText::Prefixed.new(
            "Top #{number+1} to #{number+10} non-kana CJK characters: ",
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
    File.open(@log_file) do |f|
      f.each_line.inject(0) do |sum, l|
        sum + l.scan(word).size
      end
    end
  end

  def wordfight(msg, sort = true)
    return unless msg.tail
    words = msg.tail.split(/[[:space:]]+/)
    return unless words.length >= 1

    words = words.uniq
    word_counts = words.zip(words.map { |w| count_logfile(w) })

    reply = if sort
              WordFightLayouter.new(word_counts)
            else
              LayoutableText::SimpleJoined.new(', ', word_counts.map {|w, s| "#{w} (#{s})"})
            end

    msg.reply(reply)
  end

  class WordFightLayouter < LayoutableText::Arrayed
    def initialize(arr, *args)
      # Sort by occurrence count.
      super(arr.sort_by {|_, s| -s}, *args)
    end

    protected
    def format_chunk(arr, chunk_size, is_last_line)
      chunk = arr.slice(0, chunk_size)
      # Chunk into equivalence classes by occurrence count.
      chunk = chunk.chunk {|_, s| s}.map(&:last)

      chunk.map do |equiv|
        equiv.map do |w, s|
          "#{w} (#{s})"
        end.join(' = ')
      end.join(' > ')
    end
  end
end
