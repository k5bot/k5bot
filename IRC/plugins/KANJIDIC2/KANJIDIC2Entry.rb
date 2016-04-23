# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# KANJIDIC2 entry

class KANJIDIC2
class DatabaseEntry
  VERSION = 7

  attr_accessor :kanji, # One character. The kanji represented by this entry.
                :radical_number, # Integer with classic radical number.
                :code_skip, # String with SKIP code, e.g. '1-4-3'.
                :grade, # An integer in the range of 1-10, or nil, if ungraded.
                :jlpt, # An integer in the range of 1-4, or nil, if ungraded.
                :stroke_count,
                :freq, # Kanji popularity, integer or nil.
                :readings, # Hash from :ja_on, etc. into arrays of readings.
                :meanings # Hash from :en, etc. into array of meanings.

  def self.get_japanese_stem(reading)
    result = reading.gsub('-', '') # get rid of prefix/postfix indicator -
    result.split(/\./)[0] # if dot is present, the part before it is the stem
  end

  def self.split_into_keywords(text)
    text.downcase.gsub(/[[[:punct:]]&&[^\-\*]]/, ' ').split(' ')
  end

  KANGXI_RADICALS = [
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
      %w(邑 ⻏),
      %w(酉),
      %w(釆),
      %w(里),
      %w(金 釒),
      %w(長 镸),
      %w(門),
      %w(阜 ⻖),
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

  def self.kangxi_search_extension
    f = KANGXI_RADICALS.dup
    f[1] = f[1].dup | %w(｜)
    f[3] = f[3].dup | %w(ノ)
    f[8] = f[8].dup | %w(⺅ 𠆢)
    f[11] = f[11].dup | %w(ハ)
    f[57] = f[57].dup | %w(ヨ)
    f[124] = f[124].dup | %w(⺹)
    f[139] = f[139].dup | %w(⺾)
    f[161] = f[161].dup | %w(辶)
    f[162] = f[162].dup | %w(阝)
    f[169] = f[169].dup | %w(阝)
    f[198] = f[198].dup | %w(麦)
    f[200] = f[200].dup | %w(黄)
    f[202] = f[202].dup | %w(黒)
    f[202] = f[202].dup | %w(黒)
    f[209] = f[209].dup | %w(斉)
    f[210] = f[210].dup | %w(歯)
    f
  end

  KANGXI_SEARCH_RADICALS = DatabaseEntry.kangxi_search_extension
end
end