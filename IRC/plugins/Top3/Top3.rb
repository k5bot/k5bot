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
    :top3 => "displays the top 3 Japanese writers of the month. optional .top3 exclude user1 user2... (made by amigojapan)",
    :rank => "displays the rank of the user(made by amigojapan)",
  }
  Dependencies = [ :StorageYAML ]

  def afterLoad
    @locked = false
    @storage = @plugin_manager.plugins[:StorageYAML]
    @top3 = @storage.read('Top3') || {}
  end

  def beforeUnload
    "Plugin is busy." if @locked
    @storage = nil
    @top3 = nil
  end

  def top3(msg)
    out=""
    unsorted=Array.new
    splitmsg=msg.message.split#we need this later to get the people to exclude
    if splitmsg.include?("exclude")
      exclude_array=splitmsg.drop(splitmsg.index("exclude")+1) #make exclude list
    end
    @top3.each{|data|
      #puts data
      #msg.reply data.to_s
      years=JSON.parse(data[1])
      #msg.reply years.to_s
      if not years[Date.today.year.to_s].nil? #year not found
        if not years[Date.today.year.to_s][Date.today.mon.to_s].nil? #display only the entries for the current month
          #msg.reply "not nil"
          if not exclude_array.nil?
            if not exclude_array.include?(data[0])#data[0] is the nickname
              unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s],data[0]])
              #msg.reply  "here1"+data[0]
            end
          else 
            unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s],data[0]])
            #msg.reply  "here2"
          end
        end
      end
      years=nil
      #msg.reply unsorted.to_s
    }
    sorted=unsorted.sort.reverse
    #puts sorted
    rank=0
    sorted.take(3).each{|data|
      rank=rank+1
      out=out+" #"+rank.to_s+" "+data[1]+" CJK chars:"+data[0].to_s
    }
    rank=0
    place=0
    sorted.each{|data|
      place=place+1
      if data[1] == msg.nick
        rank=place
      end
    }
    if @top3.include? msg.nick
      #current_user = @top3[msg.nick][0]
      years=JSON.parse(@top3[msg.nick])
      if years[Date.today.year.to_s].nil?
          current_user = 0
        else
          if years[Date.today.year.to_s][Date.today.mon.to_s].nil?
            current_user = 0
          else
            current_user = years[Date.today.year.to_s][Date.today.mon.to_s]
        end
      end
      years=nil
    else
      current_user = 0          
    end      
    out=out+" | "
    out=out+msg.nick+"'s CJK count is: " + current_user.to_s
    if rank == 0
      out=out+" "+msg.nick+" has not typed any Japanese this month :("
    else
      out=out+", currently ranked #" + rank.to_s + " of " + place.to_s
    end
    msg.reply  out
    #I added these just to make sure this is not causing the plugin to have a memory leak
    unsorted=nil
    sorted=nil
  end

  def rank(msg)
    person=msg.message.split(/ /)[1]# get parameter
    if person == nil
      person = msg.nick
    end
    out=""
    unsorted=Array.new
    @top3.each{|data|
      #puts data
      #if data[1][1].to_s == Date.today.mon.to_s #display only the entries for the current month
      #  unsorted.push([data[1][0],data[0]])
      #end
      years=JSON.parse(data[1])
      #msg.reply years.to_s
      if not years[Date.today.year.to_s].nil? #year not found
        if not years[Date.today.year.to_s][Date.today.mon.to_s].nil? #display only the entries for the current month
          #msg.reply "not nil"
          unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s],data[0]])
        end
      end
      years=nil
    }
    sorted=unsorted.sort.reverse
    rank=0
    place=0
    sorted.each{|data|
      place=place+1
      if data[1] == person
        rank=place
      end
    }
    if @top3.include? person
      #current_user = @top3[person][0]
      years=JSON.parse(@top3[person])
      if not years[Date.today.year.to_s].nil? #year not found
        if not years[Date.today.year.to_s][Date.today.mon.to_s].nil? #
          current_user = years[Date.today.year.to_s][Date.today.mon.to_s]
        else
          current_user = 0
        end
      else
        current_user = 0
      end
      years=nil
    else
      current_user = 0          
    end      
    out=out+person+"'s CJK count is: " + current_user.to_s
    if current_user == 0
      out=out+" "+person+" has not typed any Japanese this month :("
    else
      out=out+", currently ranked #" + rank.to_s + " of " + place.to_s
    end
    msg.reply  out
    #I added these just to make sure this is not causing the plugin to have a memory leak
    unsorted=nil
    sorted=nil
  end

  def count(msg)
    s2=msg.message.split(//)
    chars=0
    s2.each{|s| 
    	if s.contains_cjk? == true
    		chars=chars+1	
    	end
    }
    #msg.reply @top3[msg.nick].nil?.to_s
    if @top3[msg.nick].nil? #no data add yearly and monthly arrays
      years={}
      years[Date.today.year.to_s]={}
      years[Date.today.year.to_s][Date.today.mon.to_s]=chars
      @top3[msg.nick] =years.to_json
      @storage.write('Top3', @top3)
      years=nil
      return
    end
    #if years[Date.today.year].nil? #new year
    #  years[Date.today.year]={}
    #end
    #if years[Date.today.year][Date.today.mon].nil? #new month
    #  years[Date.today.year][Date.today.mon]=
    #end    
    if chars > 0
      years=JSON.parse(@top3[msg.nick])
      if years[Date.today.year.to_s].nil?
        years[Date.today.year.to_s]={}
      end
      if years[Date.today.year.to_s][Date.today.mon.to_s].nil?
          years[Date.today.year.to_s][Date.today.mon.to_s]=0
      end
      years[Date.today.year.to_s][Date.today.mon.to_s]+=chars
      @top3[msg.nick] =years.to_json
      #msg.reply years[Date.today.year.to_s][Date.today.mon.to_s]
      #if @top3.include? msg.nick
      #  @top3[msg.nick] = [@top3[msg.nick][0]+chars,Date.today.mon]
      #else
      #  @top3[msg.nick] = [chars,Date.today.mon]          
      #end
      @storage.write('Top3', @top3)
    end
  end

  def on_privmsg(msg)
    if msg.bot_command == :top3
      top3(msg)
    elsif msg.bot_command == :rank
      rank(msg)
    elsif !msg.private? and !msg.bot_command
      count(msg)
    end
  end
  rescue Exception => e
    @top3["error message"] =  e.message  
    @top3["error backtrace"] =  e.backtrace.inspect  
    @storage.write('Top3', @top3)
end
#Add year tracking
#add anual top3
#Add .rank command so we can see what rank other people have(done)
#request to keep track of nicks even if they change nick
#nick = msg.tail || msg.nick
#user = msg.bot.find_user_by_nick(nick)
#futoshi: .top3 without futoshi みたいのはどう？w
#corelax: btw how about this command -> .top3at 201507