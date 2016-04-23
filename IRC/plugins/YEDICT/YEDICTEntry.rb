# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# YEDICT entry

require 'set'

class YEDICT
class ParsedEntry
  VERSION = 2

  attr_reader :raw

  attr_reader :cantonese,
              :mandarin,
              :jyutping

  def initialize(raw)
    @raw = raw
    @cantonese = nil
    @mandarin = nil
    @jyutping = nil
    @english = nil
    @keywords = nil
  end

  # noinspection RubyStringKeysInHashInspection
  UNBALANCED_ENTRIES = {
    '巴' => %w(巴 巴),
    '應儘 責 应尽之责' => ['應儘 責', '应尽之责'],
    '蛋炒 飯 蛋炒饭' => %w(蛋炒飯 蛋炒饭),
    '食鹽多過你食米，行橋多過你行路 食盐多过你食米, 行桥多过你行路' => %w(食鹽多過你食米，行橋多過你行路 食盐多过你食米，行桥多过你行路),
    '電時分複用 电制水泥' => nil,
    '高斯分佈 高斯分OH' => nil,
    '馬漢九裡香酸鹼 马汉九里香碱' => nil,
    '無釐 无厘头' => nil,
    '工作流管理系統 工作流管理系}q' => nil,
    '春天夏天秋天冬天 在一天中出現 我的心情不會隨著它改變 從小生活在這高原 這塊牧場的邊緣 早unknown經習慣了那是自然 當藍白雲草原牧場 浮現在我眼 春天夏天秋天冬天 在一天中出现 我的心情不会随著它改变 从小生活在这高原 这块牧场的边缘 早己经习惯了那是自然 当蓝白云草原牧场 浮现在我眼前' => nil,
    '豐沙爾分餐制 丰沙尔' => nil,
    '核心價 核心价??' => nil,
    '首都機場道交通線 首都机场轨道交通线' => nil,
    '印浮水印於 印水印于' => nil,
    '軟光 “软光' => nil,
    '插針都插唔入 插针針都插唔入' => nil,
    '托杉唔識轉膊 托杉都唔识转膊' => nil,
    '托柒唔識轉膊 托柒都唔识转膊' => nil,
    '一言驚醒夢人 一言惊醒梦中人' => nil,
  }

  def parse
    m = @raw.match(/^([^\[]+)\[([^\]]*)\]/)
    raise "\nMatch failed on #{@raw}" unless m

    words_preprocessed = m[1].gsub(/[[[:space:]]\uFEFF]+/, ' ').strip
    words = words_preprocessed.split(' ')

    unless words.size > 0 && words.size % 2 == 0
      # some entries are split by /
      words = words_preprocessed.split('/')
      unless words.size == 2 && words[0].size == words[1].size
        words = UNBALANCED_ENTRIES[words_preprocessed]
        unless words
          raise "\nMatch failed, can't distinguish cantonese from mandarin in #{@raw}"
        end
      end
    end

    @cantonese = words.shift(words.size / 2).join(' ')
    @mandarin = words.join(' ')
    @jyutping = m[2].strip

    unless @cantonese.size == @mandarin.size
      if UNBALANCED_ENTRIES.include?(words_preprocessed)
        words = UNBALANCED_ENTRIES[words_preprocessed]
        @cantonese, @mandarin = words if words
      else
        raise "\nMatch failed, can't distinguish cantonese from mandarin in #{@raw}"
      end
    end
  end

  # Returns an array of the English translations and meta information.
  def english
    @english ||= @raw.split('/')[1..-1].map{|e| e.strip}
  end

  # Returns a list of keywords created from the English translations and meta information.
  # Each keyword is a symbol.
  def keywords
    @keywords ||= english.flat_map { |e| ParsedEntry.split_into_keywords(e) }.sort.uniq
  end

  def self.split_into_keywords(text)
     text.downcase.gsub(/[^a-z0-9'\- ]/, '').split.map { |e| e.strip.to_sym }
  end

  def to_s
    @raw.dup
  end
end
end