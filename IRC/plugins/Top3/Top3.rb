# encoding: utf-8
# This plugin was developed for the K5 project by amigojapan
# See files README.md and COPYING for copyright and licensing information.

# Example plugin
class String
  def contains_cjk?
    !!(self =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)
  end
end

require_relative '../../IRCPlugin'
require 'date'

class Top3 < IRCPlugin
  Description = "top3 gives the top 3 Japanese writers of the month (made by amigojapan)"
  Commands = {
    :top3 => "displays the top 3 Japanese writers of the month (made by amigojapan)",
  }
  Dependencies = [ :Clock, :StorageYAML ]

  def afterLoad
    @locked = false
    @clock = @plugin_manager.plugins[:Clock]
    @storage = @plugin_manager.plugins[:StorageYAML]
    @top3 = @storage.read('Top3') || {}
  end

  def beforeUnload
    "Plugin is busy." if @locked
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :top3
      msg.reply "Top 3 Japanese writers of this month:"
      out=""
      unsorted=Array.new
      @top3.each{|data|
        #puts data
        if data[1][1].to_s == Date.today.mon.to_s #display only the entries for the current month
          unsorted.push([data[1][0],data[0]])
        end
      }
      sorted=unsorted.sort.reverse
      puts sorted
      rank=0
      sorted.take(3).each{|data|
        rank=rank+1
        out=out+" #"+rank.to_s+" "+data[1]+" CJK chars:"+data[0].to_s
      }
      rank=0
      place=0
      sorted.each{|data|
        place=place+1
        if data[1] == msg.user.name
          rank=place
        end
      }
      msg.reply out
      if @top3.include? msg.user.name
        current_useer = @top3[msg.user.name][0]
      else
        current_useer = 0          
      end      
      out=""
      out=msg.user.name+"'s CJK count is: " + current_useer.to_s
      if rank == 0
        out=" this person has not typed any Japanese this month :("
      else
        out=out+", currently ranked #" + rank.to_s + " of " + place.to_s
      end
      msg.reply  out
    else
      s2=msg.message.split(//)
      chars=0
      s2.each{|s| 
      	if s.contains_cjk? == true
      		chars=chars+1	
      	end
      }
      if chars > 0
        if @top3.include? msg.user.name
          @top3[msg.user.name] = [@top3[msg.user.name][0]+chars,Date.today.mon]
        else
          @top3[msg.user.name] = [chars,Date.today.mon]          
        end
        @storage.write('Top3', @top3)
      end
      #this would display how manyc japanese chars where typed msg.reply @top3[msg.user.name][0].to_s
    end
  end
end