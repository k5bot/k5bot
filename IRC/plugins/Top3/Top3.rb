# encoding: utf-8
# This plugin was developted for the K5 project by amigojapan
# See files README.md and COPYING for copyright and licensing information.

# Top3 plugin

require 'set'
require 'uri'
require 'date'
require 'net/http'

require_relative '../../IRCPlugin'

class Top3 < IRCPlugin
  DESCRIPTION = 'top3 gives the top 3 Japanese writers of the month (made by amigojapan)'
  COMMANDS = {
    :top3 => 'displays the top 3 Japanese writers of the month. optional .top3 exclude user1 user2... (made by amigojapan)',
    :rank => 'displays the rank and stats of given user (omitting name means current user, integer means user with that rank) (made by amigojapan)',
    :chart => 'shows a chart of user progress. Usage: .chart or .chart user1 user2 etc (made by amigojapan)',
    #:chart_top3 => 'shows a chart of you and the top3 users of this month, usage .chart_top3 exclude user1 user2... (made by amigojapan)',
    :opt_out => 'Takes away permision for people to see your data (made by amigojapan)',
    :reopt_in => 'Regives permision of people to see your data (made by amigojapan)',
    :mlist => 'shows the rank list for this month (made by amigojapan)'
  }
  DEPENDENCIES = [:StorageYAML]

  CHART_COLORS = %w(ff0000 0000ff 00ff00 ff00ff ffff00 00ffff)

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
    elsif msg.bot_command == :mlist
      mlist(msg)
    elsif !msg.private? and !msg.bot_command
      count(msg)
    end
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

  def chart_top3(msg)
  end

  def chart(msg)
    nicks = msg.tail ? msg.tail.split : []
    nicks = [msg.nick] if nicks.empty?

    if nicks.size > CHART_COLORS.size
      msg.reply "Too many nicks specified (at most #{CHART_COLORS.size} supported)."
      return
    end

    person_data = nicks.map do |person|
      if @opt_outs[person] == 'opted-out'
        msg.reply "Sorry, #{person} has opted out."
        return
      end
      data = @top3[person] && JSON.parse(@top3[person])
      unless data && !data.empty?
        msg.reply "Sorry, we have no data for #{person}, check spelling."
        return
      end

      [person, data]
    end

    person_data = person_data.map do |person, data|
      data = data.flat_map do |year, months|
        year = year.to_i
        months.map do |month, counter|
          [[year, month.to_i], counter.to_i]
        end
      end.sort

      [person, Hash[data]]
    end

    person_data = Hash[person_data]

    timeline = person_data.values.flat_map(&:keys).sort.uniq
    timeline = timeline[-24..-1] if timeline.size > 24

    max = person_data.values.flat_map(&:values).max

    prev_year = 0
    timeline_labels = timeline.map do |year, month|
      if year == prev_year
        "|#{month}"
      else
        prev_year = year
        "|#{year} #{month}"
      end
    end.join

    counter_labels = "|0|#{max/4}|mid #{max/2}|#{(max*3)/4}|max #{max}"

    data_points = person_data.map do |_, data|
      timeline.map do |time|
        data[time] ? ((100 * data[time].to_f) / max).to_i : -1
      end.join(',')
    end.join('|')

    charturl = URI('https://chart.googleapis.com/chart')
    params = {
        :cht => 'lc',
        :chs => 500,
        :chxt => 'x,y',
        :chdl => nicks.join('|'), #TODO: escape vertical bars in nicks somehow
        :chco => CHART_COLORS[0, nicks.size].join(','),
        :chxl => "0:#{timeline_labels}|1:#{counter_labels}",
        :chd => "t:#{data_points}",
    }
    charturl.query = URI.encode_www_form(params)

    tiny_url = tinyurlify(charturl)

    msg.reply("Chart: #{tiny_url}")
  end

  def get_exclude_array(args = '')
    splitmsg=args.split #we need this later to get the people to exclude
    if splitmsg.include?('exclude')
      exclude_array = splitmsg.drop(splitmsg.index('exclude')+1) #make exclude list
    else
      exclude_array = []
    end

    exclude_array = Set.new(exclude_array)

    exclude_array + @opt_outs.find_all do |_, v|
      v == 'opted-out'
    end.map(&:first)
  end

  def get_top_list(exclude_array = [])
    date_now = Date.today
    year_now = date_now.year.to_s
    month_now = date_now.mon.to_s

    unsorted = []
    @top3.each do |nick, data|
      next if exclude_array.include?(nick)
      years = JSON.parse(data)
      next unless years[year_now] #year not found
      next unless years[year_now][month_now] #display only the entries for the current month

      unsorted << [years[year_now][month_now], nick]
    end

    unsorted.sort.reverse
  end

  def mlist(msg)
    exclude_array = get_exclude_array(msg.tail || '')
    sorted = get_top_list(exclude_array)

    out = sorted.each_with_index.map do |(cnt, nick), rank|
      " ##{rank+1} #{nick} CJK chars: #{cnt}\n"
    end.join

    gist_reply = gistify(out)
    tiny_url = tinyurlify(gist_reply['files']['rank.txt']['raw_url'])

    msg.reply("Ranked list: #{tiny_url}")
  end

  GIST_URI = URI('https://api.github.com/gists')

  def gistify(out)
    payload = {
        'description' => "Ranked list of users for #{Time.now} server time\n",
        'public' => false,
        'files' => {
            'rank.txt' => {
                'content' => out
            }
        }
    }

    req = Net::HTTP::Post.new(GIST_URI.path)
    req.body = payload.to_json

    # GitHub API is strictly via HTTPS, so SSL is mandatory
    res = Net::HTTP.start(GIST_URI.hostname, GIST_URI.port, :use_ssl => true) do |http|
      http.request(req)
    end

    JSON.parse(res.body)
  end

  def top3(msg)
    exclude_array = get_exclude_array(msg.tail || '')
    sorted = get_top_list(exclude_array)

    sorted_take = sorted.take(3)
    out = sorted_take.each_with_index.map do |(cnt, nick), rank|
      " ##{rank+1} #{nick} CJK chars: #{cnt}"
    end.join

    unless sorted_take.any? {|_, nick| nick == msg.nick}
      out += ' | ' + format_user_stats(msg.nick, sorted, exclude_array)
    end

    msg.reply(out)
  end

  def rank(msg)
    exclude_array = get_exclude_array
    sorted = get_top_list(exclude_array)

    person = msg.tail ? msg.tail.split : []
    person = person.first || msg.nick

    rank = Top3.get_int(person)
    if rank
      person = if rank < 0
                 sorted[rank]
               elsif rank > 0
                 sorted[rank - 1]
               end
      unless person
        msg.reply("No person with such rank (#{sorted.size} total).")
        return
      end

      # extract nick
      person = person[1]
    end

    out = format_user_stats(person, sorted, exclude_array)

    msg.reply(out)
  end

  def format_user_stats(person, sorted, exclude_array)
    if exclude_array.include?(person)
      "#{person}'s data cannot be displayed; he opted out or was excluded."
    else
      rank = sorted.index do |_, nick|
        nick == person
      end

      if rank
        current_user, _ = sorted[rank]
        "#{person}'s CJK count is: #{current_user}, currently ranked ##{rank+1} of #{sorted.size}"
      else
        "#{person} has not typed any Japanese this month :("
      end
    end
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

  TINYURL_URL = URI('http://tinyurl.com/api-create.php')
  def tinyurlify(url)
    t = TINYURL_URL.dup
    t.query = URI.encode_www_form(:url => url)
    Net::HTTP.get(t)
  end

  private

  def self.get_int(s)
    return unless s
    index_str = s[/^\s*-?[0-9０１２３４５６７８９]+\s*$/]
    return unless index_str
    index_str.tr!('０１２３４５６７８９','0123456789')
    index_str.to_i
  end
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
