#!/bin/env ruby
# encoding: utf-8

require_relative '../../IRCPlugin'

class Manyougana < IRCPlugin
  DESCRIPTION = "Rômazi to man'yôgana converter."
  COMMANDS = {
    :manyougana => "Converts from rômazi to man'yôgana. Requires numeral notation for Old Japanese vowels. Since there exist multiple man'yôgana for each mora, the final choice will be random."
  }

  def on_privmsg(msg)
    case msg.botcommand
      when :manyougana
        return unless msg.tail
        msg.reply convert(msg.tail)
    end
  end

  MANYOUGANA = { "a" => "阿安英足", "i" => "伊怡以異已移射五", "u" => "宇羽于有卯烏得", "e" => "衣依愛榎", "o" => "意憶於應", "ka" => "可何加架香蚊迦", "ki1" => "可何加架香蚊迦", "ki2" => "貴紀記奇寄忌幾木城", "ku" => "久九口丘苦鳩来", "ke1" => "祁家計係價結鶏", "ke2" => "気既毛飼消", "ko1" => "古姑枯故侯孤児粉", "ko2" => "己巨去居忌許虚興木", "sa" => "左佐沙作者柴紗草散", "si" => "子之芝水四司詞斯志思信偲寺侍時歌詩師紫新旨指次此死事准磯為", "su" => "寸須周酒州洲珠数酢栖渚", "se" => "世西斉勢施背脊迫瀬", "so1" => "宗祖素蘇十", "so2" => "所則曾僧増憎衣背苑", "ta" => "太多他丹駄田手立", "ti" => "知智陳千乳血茅", "tu" => "都豆通追川津", "te" => "堤天帝底手代直", "to1" => "刀土斗度戸利速", "to2" => "止等登澄得騰十鳥常跡", "na" => "那男奈南寧難七名魚菜", "ni" => "二人日仁爾迩尼耳柔丹荷似煮煎", "nu" => "奴努怒農濃沼宿", "ne" => "禰尼泥年根宿", "no1" => "努怒野", "no2" => "乃能笑荷", "fa" => "八方芳房半伴倍泊波婆破薄播幡羽早者速葉歯", "fi1" => "比必卑賓日氷飯負嬪臂避臂匱", "fi2" => "非悲斐火肥飛樋干乾彼被秘", "fu" => "不否布負部敷経歴", "fe1" => "平反返弁弊陛遍覇部辺重隔", "fe2" => "閉倍陪拝戸経", "fo" => "凡方抱朋倍保宝富百帆穂", "ma" => "万末馬麻摩磨満前真間鬼", "mi1" => "民彌美三水見視御", "mi2" => "未味尾微身実箕", "mu" => "牟武無模務謀六", "me1" => "売馬面女", "me2" => "梅米迷昧目眼海", "mo1" => "毛畝蒙木問聞", "mo2" => "方面忘母文茂記勿物望門喪裳藻", "ya" => "也移夜楊耶野八矢屋", "yu" => "由喩遊湯", "ye" => "曳延要遥叡兄江吉枝衣", "yo1" => "用容欲夜", "yo2" => "与余四世代吉", "ra" => "良浪郎楽羅等", "ri" => "里理利梨隣入煎", "ru" => "留流類", "re" => "礼列例烈連", "ro1" => "路漏", "ro2" => "呂侶", "wa" => "和丸輪", "wi" => "位為謂井猪藍", "we" => "廻恵面咲", "wo" => "乎呼遠鳥怨越少小尾麻男緒雄", "ga" => "我何賀", "gi1" => "伎祇芸岐儀蟻", "gi2" => "疑宜義擬", "gu" => "具遇隅求愚虞", "ge1" => "下牙雅夏", "ge2" => "義気宜礙削", "go1" => "吾呉胡娯後籠児悟誤", "go2" => "其期碁語御馭凝", "za" => "社射謝耶奢装蔵", "zi" => "自士仕司時尽慈耳餌児弐爾", "zu" => "受授殊儒", "ze" => "是湍", "zo1" => "俗", "zo2" => "序叙賊存茹鋤", "da" => "陀太大嚢", "di" => "遅治地恥尼泥", "du" => "豆頭弩", "de" => "代田泥庭伝殿而涅提弟", "do1" => "土度渡奴怒", "do2" => "特藤騰等耐抒杼", "ba" => "伐婆磨魔", "bi1" => "婢鼻弥", "bi2" => "備肥飛乾眉媚", "bu" => "夫扶府文柔歩部", "be1" => "弁便別部", "be2" => "倍毎", "bo" => "煩菩番蕃" }

  def convert(ro)
    MANYOUGANA.reverse_each{ |k, v| ro = ro.gsub( k, v.split("").sample ) }
    return ro
  end
end
