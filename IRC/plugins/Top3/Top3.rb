# encoding: utf-8
# This plugin was developted for the K5 project by amigojapan
# See files README.md and COPYING for copyright and licensing information.

# Top3 plugin

require 'net/http'
require_relative '../../IRCPlugin'
require 'date'

class Top3 < IRCPlugin
  Description = 'top3 gives the top 3 Japanese writers of the month (made by amigojapan)'
  Commands = {
    :top3 => 'displays the top 3 Japanese writers of the month. optional .top3 exclude user1 user2... (made by amigojapan)',
    :rank => 'displays the rank of the user(made by amigojapan)',
    :chart => 'shows a chart of user progress examples: .chart or .chart user (made by amigojapan)',
    :chart_vs => 'shows a chart of user progress of user versus user, usage: .chart_vs user1 user2 (made by amigojapan)',
    :chart_top3 => 'shows a chart of you and the top3 users of this month, usage .chart_top3 exclude user1 user2... (made by amigojapan)',
    :opt_out => 'Takes away permision for people to see your data (made by amigojapan)',
    :reopt_in => 'Regives permision of people to see your data (made by amigojapan)',
    :mlist => 'shows the rank list for this month (made by amigojapan)'
  }
  Dependencies = [ :StorageYAML ]

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]
    @top3 = @storage.read('Top3') || {}
    @opt_outs = @storage.read('Optouts') || {}
  end

  def beforeUnload
    @storage = nil
    @top3 = nil
    @opt_outs = nil

    nil
  end

  def opt_out(msg)
    @opt_outs[msg.nick]='opted-out'
    @storage.write('Optouts', @opt_outs)
    msg.reply 'you have opted out'
  end

  def reopt_in(msg)
    @opt_outs[msg.nick]='reopted-in'
    @storage.write('Optouts', @opt_outs)
    msg.reply 'you have re-opted in'
  end

  def chart_vs(msg)
    user1=msg.message.split(/ /)[1] # get parameter
    user2=msg.message.split(/ /)[2] # get parameter
    if user1 == nil or user2 == nil
      msg.reply 'Usage: .chart_vs user1 user2'
      return
    end
    if @top3[user1].nil? or @top3[user2].nil? #year not found
      msg.reply 'Sorry, we have no data for one of these users, check spelling.'
      return
    end
    charturl1='https://chart.googleapis.com/chart?cht=lc&chs=500&chd=t:'
    user1_years=JSON.parse(@top3[user1])
    user2_years=JSON.parse(@top3[user2])
    @opt_outs.each_key do |optoutskey|
      if optoutskey==user1
        if @opt_outs[optoutskey]=='opted-out'
          msg.reply 'Sorry, ' + user1 + ' has opted out of charting'
          return
        end
      end
      if optoutskey==user2
        if @opt_outs[optoutskey]=='opted-out'
          msg.reply 'Sorry, ' + user2 + ' has opted out of charting'
          return
        end
      end
    end
    user1_unsorted_chart=Array.new
    user2_unsorted_chart=Array.new
    charturl2=''
    charturl4=''
    charturl4+='|' #for the first year only
    user1_labels=''
    user2_labels=''
    month_counter=1
    user1_years.each_key do |year|
      user1_years[year].each_key do |month|
        user1_unsorted_chart.push(user1_years[year][month])
        user1_labels+=month_counter.to_s+'|'
        month_counter+=1
      end
    end
    month_counter=1
    user1_labels=user1_labels.chomp('|')
    user2_years.each_key do |year|
      user2_years[year].each_key do |month|
        user2_unsorted_chart.push(user2_years[year][month])
        user2_labels+= month_counter.to_s+'|'
        month_counter+=1
      end
    end
    user2_labels=user2_labels.chomp('|')
    if user1_labels.length > user2_labels.length
      charturl4+=user1_labels
    else
      charturl4+=user2_labels
    end
    user1_sorted_chart = user1_unsorted_chart.sort
    max1=user1_sorted_chart.last
    user2_sorted_chart = user2_unsorted_chart.sort
    max2=user2_sorted_chart.last
    max=[max1, max2].max
    user1longest=false
    if user1_sorted_chart.length > user2_sorted_chart.length
      user1longest=true
    end
    #all values / maximum value * 100
    current=0
    user1_unsorted_chart.each do
      scaled_value=(user1_unsorted_chart[current].to_f/max*100).to_i
      charturl2+=scaled_value.to_s+','
      current=current+1
    end
    unless user1longest
      charturl2+='0,'*(user2_sorted_chart.length - user1_sorted_chart.length)
    end
    charturl2=charturl2.chomp(',')
    charturl2+='%7C'
    current=0
    user2_unsorted_chart.each do
      scaled_value=(user2_unsorted_chart[current].to_f/max*100).to_i
      charturl2+=scaled_value.to_s+','
      current=current+1
    end
    if user1longest
      charturl2+='0,'*(user1_sorted_chart.length - user2_sorted_chart.length)
    end
    charturl2=charturl2.chomp(',')
    charturl4+= '|1:|0|' + (max*1/4).to_s + '|mid%20'+ (max/2).to_s + '|' + (max*3/4).to_s + '|max%20' +max.to_s
    charturl3='&chxt=x,y&chxl=0:'
    charturl5='&chdl='
    charturl6=user1+'|'+user2
    charturl7='&chco='
    charturl8='ff0000,0000ff'
    charturl=charturl1+charturl2+charturl3+charturl4+charturl5+charturl6+charturl7+charturl8
    msg.reply 'chart(months are months since record taking): ' + Net::HTTP.get('tinyurl.com', '/api-create.php?url='+charturl)
  end

  def chart_top3(msg)
  end

  def chart(msg)
    person=msg.message.split(/ /)[1] # get parameter
    if person == nil
      person = msg.nick
    end
    if @top3[person].nil? #year not found
      msg.reply 'Sorry, we have no data for this user, check spelling.'
      return
    end
    charturl1='https://chart.googleapis.com/chart?cht=lc&chs=500&chd=t:'
    years=JSON.parse(@top3[person])
    @opt_outs.each_key do |optoutskey|
      if optoutskey==person
        if @opt_outs[optoutskey]=='opted-out'
          msg.reply 'Sorry, this user has opted out'
          return
        end
      end
    end
    unsorted_chart=Array.new
    prev_year=0
    charturl2=''
    charturl4=''
    charturl4+='|' #for the first year only
    years.each_key do |year|
      years[year].each_key do |month|
        unsorted_chart.push(years[year][month])
        if year.to_i>prev_year
          prev_year=year.to_i
          charturl4+=year+'%20'
        end
        charturl4+=month.to_s+'|'
      end
    end
    charturl4=charturl4.chomp('|')
    sorted_chart = unsorted_chart.sort
    max=sorted_chart.last
    #all values / maximum value * 100
    current=0
    unsorted_chart.each do
      scaled_value=(unsorted_chart[current].to_f/max*100).to_i
      charturl2+=scaled_value.to_s+','
      current=current+1
    end
    charturl2=charturl2.chomp(',')
    charturl4+= '|1:|0|' + (max*1/4).to_s + '|mid%20'+ (max/2).to_s + '|' + (max*3/4).to_s + '|max%20' +max.to_s
    charturl3='&chxt=x,y&chxl=0:'
    charturl5='&chdl='
    charturl6=person
    charturl7='&chco='
    charturl8='ff0000'
    charturl=charturl1+charturl2+charturl3+charturl4+charturl5+charturl6+charturl7+charturl8
    msg.reply 'chart: ' + Net::HTTP.get('tinyurl.com', '/api-create.php?url='+charturl)
  end

  def mlist(msg)
    out=''
    unsorted=Array.new
    splitmsg=msg.message.split #we need this later to get the people to exclude
    @opt_outs.each_key do |optoutskey|
      if @opt_outs[optoutskey]=='opted-out'
        unless splitmsg.include?('exclude')
          splitmsg.push('exclude')
        end
        splitmsg.push(optoutskey)
      end
    end
    if splitmsg.include?('exclude')
      exclude_array=splitmsg.drop(splitmsg.index('exclude')+1) #make exclude list
    else
      exclude_array=Array.new
    end
    @top3.each do |data|
      years=JSON.parse(data[1])
      if years[Date.today.year.to_s] #year not found
        if years[Date.today.year.to_s][Date.today.mon.to_s] #display only the entries for the current month
          if exclude_array
            unless exclude_array.include?(data[0]) #data[0] is the nickname
              unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s], data[0]])
            end
          else
            unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s], data[0]])
          end
        end
      end
    end
    sorted=unsorted.sort.reverse
    rank=0
    sorted.each do |data|
      rank=rank+1
      out=out+' #'+rank.to_s+' '+data[1]+' CJK chars:'+data[0].to_s+"\n"
    end

    uri = URI('https://api.github.com/gists')

    payload = {
      'description' => 'Ranked list of users for ' +Time.now.to_s+" server time\n",
      'public' => false,
      'files' => {
        'rank.txt' => {
          'content' => out
        }
      }
    }

    req = Net::HTTP::Post.new(uri.path)
    req.body = payload.to_json

    # GitHub API is strictly via HTTPS, so SSL is mandatory
    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
      http.request(req)
    end

    gist_reply=JSON.parse(res.body)
    msg.reply 'Ranked list: ' + Net::HTTP.get('tinyurl.com', '/api-create.php?url='+gist_reply['files']['rank.txt']['raw_url'])
  end


  def top3(msg)
    out=''
    unsorted=Array.new
    splitmsg=msg.message.split #we need this later to get the people to exclude
    @opt_outs.each_key do |optoutskey|
      if @opt_outs[optoutskey]=='opted-out'
        unless splitmsg.include?('exclude')
          splitmsg.push('exclude')
        end
        splitmsg.push(optoutskey)
      end
    end
    if splitmsg.include?('exclude')
      exclude_array=splitmsg.drop(splitmsg.index('exclude')+1) #make exclude list
    else
      exclude_array=Array.new
    end
    @top3.each do |data|
      years=JSON.parse(data[1])
      if years[Date.today.year.to_s] #year not found
        if years[Date.today.year.to_s][Date.today.mon.to_s] #display only the entries for the current month
          if exclude_array
            unless exclude_array.include?(data[0]) #data[0] is the nickname
              unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s], data[0]])
            end
          else
            unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s], data[0]])
          end
        end
      end
    end
    sorted=unsorted.sort.reverse
    rank=0
    sorted.take(3).each do |data|
      rank=rank+1
      out=out+' #'+rank.to_s+' '+data[1]+' CJK chars:'+data[0].to_s
    end
    rank=0
    place=0
    sorted.each do |data|
      place=place+1
      if data[1] == msg.nick
        rank=place
      end
    end
    if @top3.include? msg.nick
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
    else
      current_user = 0
    end
    out=out+' | '
    if exclude_array.include?(msg.nick)
      out=out+msg.nick+"'s data cannot be displayed he opted out or was excluded"
    else
      out=out+msg.nick+"'s CJK count is: " + current_user.to_s
    end
    if rank == 0
      out=out+' '+msg.nick+' has not typed any Japanese this month :('
    else
      out=out+', currently ranked #' + rank.to_s + ' of ' + place.to_s
    end
    msg.reply out
  end

  def rank(msg)
    person=msg.message.split(/ /)[1] # get parameter
    @opt_outs.each_key do |optoutskey|
      if optoutskey==person
        if @opt_outs[optoutskey]=='opted-out'
          msg.reply 'Sorry, this user has opted out'
          return
        end
      end
    end
    if person == nil
      person = msg.nick
    end
    out=''
    unsorted=Array.new
    @top3.each do |data|
      years=JSON.parse(data[1])
      if years[Date.today.year.to_s] #year not found
        if years[Date.today.year.to_s][Date.today.mon.to_s] #display only the entries for the current month
          unsorted.push([years[Date.today.year.to_s][Date.today.mon.to_s], data[0]])
        end
      end
    end
    sorted=unsorted.sort.reverse
    rank=0
    place=0
    sorted.each do |data|
      place=place+1
      if data[1] == person
        rank=place
      end
    end
    if @top3.include? person
      years=JSON.parse(@top3[person])
      if years[Date.today.year.to_s] #year not found
        if years[Date.today.year.to_s][Date.today.mon.to_s] #
          current_user = years[Date.today.year.to_s][Date.today.mon.to_s]
        else
          current_user = 0
        end
      else
        current_user = 0
      end
    else
      current_user = 0
    end
    out=out+person+"'s CJK count is: " + current_user.to_s
    if current_user == 0
      out=out+' '+person+' has not typed any Japanese this month :('
    else
      out=out+', currently ranked #' + rank.to_s + ' of ' + place.to_s
    end
    msg.reply out
  end

  def contains_cjk?(s)
    !!(s =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)
  end

  def count(msg)
    s2=msg.message.split(//)
    chars=0
    s2.each do |s|
      if contains_cjk?(s)
        chars=chars+1
      end
    end
    if @top3[msg.nick].nil? #no data add yearly and monthly arrays
      years={}
      years[Date.today.year.to_s]={}
      years[Date.today.year.to_s][Date.today.mon.to_s]=chars
      @top3[msg.nick] =years.to_json
      @storage.write('Top3', @top3)
      return
    end
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
      @storage.write('Top3', @top3)
    end
  end

  def on_privmsg(msg)
    if msg.bot_command == :top3
      top3(msg)
    elsif msg.bot_command == :rank
      rank(msg)
    elsif msg.bot_command == :chart
      chart(msg)
    elsif msg.bot_command == :opt_out
      opt_out(msg)
    elsif msg.bot_command == :reopt_in
      reopt_in(msg)
    elsif msg.bot_command == :chart_top3
      chart_top3(msg)
    elsif msg.bot_command == :chart_vs
      chart_vs(msg)
    elsif msg.bot_command == :mlist
      mlist(msg)
    elsif !msg.private? and !msg.bot_command
      count(msg)
    end
  end
rescue Exception => e
  @top3['error message'] = e.message
  @top3['error backtrace'] = e.backtrace.inspect
  @storage.write('Top3', @top3)
end
#(done)Add year tracking
#add anual top3
#(done)Add .rank command so we can see what rank other people have
#request to keep track of nicks even if they change nick
#nick = msg.tail || msg.nick
#user = msg.bot.find_user_by_nick(nick)

#(done)futoshi: .top3 without futoshi みたいのはどう？w
#corelax: btw how about this command -> .top3at 201507
#(done)fadd opt-out for chart, because it can be used to spy on people like "how did you type 1million CJK characters over every month for the past 3 years?"
#add https to addresses. note: difficulty in ruby to do this easily because of the complex url
#(done)add an error message when the user does not exist in the charting functions
#(done)SteveTheTribble: I would like to know who is above me and behind me, and in which distance. I may add an option to make a list that displays on the web for people that dont opt out... would that be ok? https://developer.github.com/v3/gists/#create-a-gist
