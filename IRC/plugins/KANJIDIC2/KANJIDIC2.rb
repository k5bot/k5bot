# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC2 plugin
#
# The KANJIDIC2 Dictionary File (KANJIDIC2) used by this plugin comes from Jim Breen's JMdict/KANJIDIC Project.
# Copyright is held by the Electronic Dictionary Research Group at Monash University.
#
# http://www.csse.monash.edu.au/~jwb/kanjidic.html

require 'uri'

require_relative '../../IRCPlugin'

require_relative 'KANJIDIC2Entry'

class KANJIDIC2 < IRCPlugin
  Description = "A KANJIDIC2 plugin."
  Commands = {
    :k => {
        nil => "looks up a given kanji, or shows list of kanji satisfying given search terms, \
using Jim Breen's KANJIDIC2( http://www.csse.monash.edu.au/~jwb/kanjidic_doc.html ), \
and GSF kanji list kindly provided by Con Kolivas( http://ck.kolivas.org/Japanese/entries/index.html )",
        :terms1 => "Words in meanings ('west sake'), \
kun-yomi stems (in hiragana), \
on-yomi (in katakana), \
pinyin ('zhun3'), \
korean (in hangul), \
stroke count ('S10'), \
SKIP code ('P1-4-3' or just '1-4-3', see also .faq skip), \
frequency ('F15'), \
GSF frequency ('FG15'), \
grade (from 1 to 10, e.g. 'G3'), \
JLPT level (from 1 to 4, e.g. 'J2'), \
or classic radical number (from 1 to 214, e.g. 'C15')",
        :terms2 => "You can use any space-separated combination of search terms, to find kanji that satisfies them all. \
As a shortcut feature, you can also lookup kanji just by stroke count without S prefix (e.g. '.k 10'), \
if it's the only given search term",
    },
    :k? => 'same as .k, but gives out long results as a menu keyed with radicals',
    :kl => "gives a link to the kanji entry of the specified kanji at jisho.org"
  }
  Dependencies = [ :Language, :Menu ]

  MAX_RESULTS_COUNT = 3

  attr_reader :kanji, :code_skip, :stroke_count, :misc, :kanji_parts, :gsf_order

  def afterLoad
    load_helper_class(:KANJIDIC2Entry)

    @l = @plugin_manager.plugins[:Language]
    @m = @plugin_manager.plugins[:Menu]

    dict = load_dict('kanjidic2')

    @kanji = dict[:kanji]
    @code_skip = dict[:code_skip]
    @stroke_count = dict[:stroke_count]
    @misc = dict[:misc]
    @kanji_parts = dict[:kanji_parts]
    @gsf_order = dict[:gsf_order]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @gsf_order = nil
    @kanji_parts = nil
    @misc = nil
    @stroke_count = nil
    @code_skip = nil
    @kanji = nil

    @m = nil
    @l = nil

    unload_helper_class(:KANJIDIC2Entry)

    nil
  end

  def on_privmsg(msg)
    return unless msg.tail
    bot_command = msg.botcommand
    case bot_command
    when :k, :k?
      search_result = @code_skip[msg.tail]
      search_result ||= @stroke_count[msg.tail]
      search_result ||= keyword_lookup(KANJIDIC2Entry.split_into_keywords(msg.tail), @misc)
      search_result ||= extract_known_kanji(msg.tail, MAX_RESULTS_COUNT)
      if search_result
        if search_result.size <= MAX_RESULTS_COUNT
          search_result.each do |entry|
            msg.reply(format_entry(entry))
          end
        else
          kanji_map = kanji_grouped_by_radicals(search_result)
          if bot_command == :k?
            reply_with_menu(msg, generate_menu(kanji_map, 'KANJIDIC2'))
          else
            kanji_list = kanji_map.values.map do |entries|
              format_kanji_list(entries)
            end.join(' ')
            msg.reply(kanji_list)
          end
        end
      else
        msg.reply(not_found_msg(msg.tail))
      end
    when :kl
      search_result = extract_known_kanji(msg.tail, MAX_RESULTS_COUNT)
      if search_result
        search_result.each do |entry|
          msg.reply("Info on #{entry.kanji}: " + URI.escape("http://jisho.org/kanji/details/#{entry.kanji}"))
        end
      else
        msg.reply(not_found_msg(msg.tail))
      end
    end
  end

  private

  def generate_menu(lookup, name)
    menu = lookup.map do |radical_number, entries|
      description = RADICALS[radical_number-1].join(' ')

      kanji_list = if entries.size == 1
                     format_entry(entries.first)
                   else
                     format_kanji_list(entries)
                   end

      MenuNodeText.new(description, kanji_list)
    end

    MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  def extract_known_kanji(txt, max_results)
    result = []

    txt.each_char do |c|
      break if result.size >= max_results
      entry = @kanji[c]
      result << entry if entry
    end

    result unless result.empty?
  end

  def kanji_grouped_by_radicals(entries)
    radical_groups = entries.group_by do |entry|
      entry.radical_number
    end
    radical_groups.values.each do |grouped_entries|
      grouped_entries.sort_by! do |x|
        [x.freq || 100000, x.stroke_count]
      end
    end

    Hash[radical_groups.sort]
  end

  def not_found_msg(requested)
    "No hits for '#{requested}' in KANJIDIC2."
  end

  def load_dict(dict_name)
    dict = File.open("#{(File.dirname __FILE__)}/#{dict_name}.marshal", 'r') do |io|
      Marshal.load(io)
    end
    raise "The #{dict_name}.marshal file is outdated. Rerun convert.rb." unless dict[:version] == KANJIDIC2Entry::VERSION
    dict
  end

  def format_kanji_list(entries)
    entries.map do |entry|
      entry.kanji
    end.join()
  end

  def format_entry(entry)
    out = [entry.kanji]
    out << "Rad: #{entry.radical_number}"
    out << "SKIP: #{entry.code_skip.join(', ')}" unless entry.code_skip.empty?
    out << "Strokes: #{entry.stroke_count}"

    case entry.grade
    when 1..6
      out << "Grade: Kyōiku-#{entry.grade}"
    when 7..8
      out << "Grade: Jōyō-#{entry.grade-6}"
    when 9..10
      out << "Grade: Jinmeiyō-#{entry.grade-8}"
    end

    out << "JLPT: #{entry.jlpt}" if entry.jlpt

    out << "Freq: #{entry.freq}" if entry.freq

    out << "GSF: #{@gsf_order[entry.kanji]}" if @gsf_order[entry.kanji]

    out << "Parts: #{@kanji_parts[entry.kanji]}" if @kanji_parts[entry.kanji]

    order = entry.readings.dup

    format_reading(out, order, :pinyin)
    format_reading(out, order, :korean_h) do |r_list|
      r_list.map do |hangul|
        "#{hangul}(#{@l.from_hangul(hangul)[0]})"
      end.join(' ')
    end
    format_reading(out, order, :ja_on)
    format_reading(out, order, :ja_kun)
    format_reading(out, order, :nanori) do |r_list|
      "Nanori: #{r_list.join(' ')}"
    end

    while order.size > 0
      format_reading(out, order, order.keys.first)
    end

    types = [:en]
    unless entry.meanings.empty?
      types.map do |type|
        m_list = entry.meanings[type].join('} {')
        out << "{#{m_list}}" unless m_list.empty?
      end
    end

    out.join(' ▪ ')
  end

  def format_reading(out, readings, type)
    r_list = readings.delete(type)
    return unless r_list
    if block_given?
      out << yield(r_list)
    else
      out << r_list.join(' ')
    end
  end

  # Looks up keywords in the keyword hash.
  # Specified argument is a string of one or more keywords.
  # Returns the intersection of the results for each keyword.
  def keyword_lookup(words, hash)
    lookup_result = nil

    words.each do |k|
      return nil unless (entry_array = hash[k])
      if lookup_result
        lookup_result &= entry_array
      else
        lookup_result = Array.new(entry_array)
      end
    end
    return nil unless lookup_result && !lookup_result.empty?

    lookup_result
  end

  RADICALS = [
      %w(一),
      %w(丨),
      %w(丶),
      %w(丿),
      %w(乙 ⺄ 乚),
      %w(亅),
      %w(二),
      %w(亠),
      %w(人 亻),
      %w(儿),
      %w(入),
      %w(八),
      %w(冂),
      %w(冖),
      %w(冫),
      %w(几),
      %w(凵),
      %w(刀 刂),
      %w(力),
      %w(勹),
      %w(匕),
      %w(匚),
      %w(匸),
      %w(十),
      %w(卜),
      %w(卩 㔾),
      %w(厂),
      %w(厶),
      %w(又),
      %w(口),
      %w(囗),
      %w(土),
      %w(士),
      %w(夂),
      %w(夊),
      %w(夕),
      %w(大),
      %w(女),
      %w(子),
      %w(宀),
      %w(寸),
      %w(小 ⺌ ⺍),
      %w(尢 尣),
      %w(尸),
      %w(屮),
      %w(山),
      %w(巛 川 巜),
      %w(工),
      %w(己 巳 已),
      %w(巾),
      %w(干),
      %w(幺),
      %w(广),
      %w(廴),
      %w(廾),
      %w(弋),
      %w(弓),
      %w(彐 彑),
      %w(彡),
      %w(彳),
      %w(心 忄 ⺗),
      %w(戈),
      %w(戶 户 戸),
      %w(手 扌 龵),
      %w(支),
      %w(攴 攵),
      %w(文),
      %w(斗),
      %w(斤),
      %w(方),
      %w(无 旡),
      %w(日),
      %w(曰),
      %w(月),
      %w(木),
      %w(欠),
      %w(止),
      %w(歹 歺),
      %w(殳),
      %w(毋 母 ⺟),
      %w(比),
      %w(毛),
      %w(氏),
      %w(气),
      %w(水 氵 氺),
      %w(火 灬),
      %w(爪 爫),
      %w(父),
      %w(爻),
      %w(爿 丬),
      %w(片),
      %w(牙),
      %w(牛 牜 ⺧),
      %w(犬 犭),
      %w(玄),
      %w(玉 玊 王 ⺩),
      %w(瓜),
      %w(瓦),
      %w(甘),
      %w(生),
      %w(用 甩),
      %w(田),
      %w(疋 ⺪),
      %w(疒),
      %w(癶),
      %w(白),
      %w(皮),
      %w(皿),
      %w(目),
      %w(矛),
      %w(矢),
      %w(石),
      %w(示 礻),
      %w(禸),
      %w(禾),
      %w(穴),
      %w(立),
      %w(竹 ⺮),
      %w(米),
      %w(糸 糹),
      %w(缶),
      %w(网 罒 ⺲ 罓 ⺳),
      %w(羊 ⺶ ⺷),
      %w(羽),
      %w(老 耂),
      %w(而),
      %w(耒),
      %w(耳),
      %w(聿 ⺻),
      %w(肉 ⺼),
      %w(臣),
      %w(自),
      %w(至),
      %w(臼),
      %w(舌),
      %w(舛),
      %w(舟),
      %w(艮),
      %w(色),
      %w(艸 艹),
      %w(虍),
      %w(虫),
      %w(血),
      %w(行),
      %w(衣 衤),
      %w(西 襾 覀),
      %w(見),
      %w(角),
      %w(言 訁),
      %w(谷),
      %w(豆),
      %w(豕),
      %w(豸),
      %w(貝),
      %w(赤),
      %w(走 赱),
      %w(足 ⻊),
      %w(身),
      %w(車),
      %w(辛),
      %w(辰),
      %w(辵 辶 ⻌ ⻍),
      %w(邑 阝),
      %w(酉),
      %w(釆),
      %w(里),
      %w(金 釒),
      %w(長 镸),
      %w(門),
      %w(阜 阝),
      %w(隶),
      %w(隹),
      %w(雨),
      %w(青 靑),
      %w(非),
      %w(面 靣),
      %w(革),
      %w(韋),
      %w(韭),
      %w(音),
      %w(頁),
      %w(風),
      %w(飛),
      %w(食 飠),
      %w(首),
      %w(香),
      %w(馬),
      %w(骨),
      %w(高 髙),
      %w(髟),
      %w(鬥),
      %w(鬯),
      %w(鬲),
      %w(鬼),
      %w(魚),
      %w(鳥),
      %w(鹵),
      %w(鹿),
      %w(麥),
      %w(麻),
      %w(黃),
      %w(黍),
      %w(黑),
      %w(黹),
      %w(黽),
      %w(鼎),
      %w(鼓),
      %w(鼠),
      %w(鼻),
      %w(齊),
      %w(齒),
      %w(龍),
      %w(龜),
      %w(龠),
  ]
end
