# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Parser for the official F1 live timing

require 'IRC/IRCPlugin'

require 'net/http'
require 'uri'
require 'time'
require 'nokogiri'

class F1
  include IRCPlugin

  PREVIOUS_RACES = [
    'Melbourne',
    'Sakhir',
    'Shanghai',
    'Sochi',
    'Catalunya',
    'Montreal',
    'MonteCarlo',
    'Baku',
    'Spielberg',
    'Silverstone',
    'Budapest',
    'Hockenheim',
    'Spa',
    'Monza',
    'KualaLumpur',
    'Suzuka',
    'Austin',
    'MexicoCity',
    'SaoPaulo',
    'YasMarina',
  ]

  SERVERLIST = 'http://www.formula1.com/sp/static/f1/2016/serverlist/svr/serverlist.xml.js'

  DESCRIPTION = 'Parser for the official F1 live timing (2016 season)'
  COMMANDS = {
    f1pos: "displays positions in current race, or previous one given a track name (#{PREVIOUS_RACES.join(', ')})",
    f1cal: "displays the next race weekend's starting times",
  }

  def on_privmsg(msg)
    case msg.bot_command
    when :f1pos
      positions(msg)
    when :f1cal
      calendar(msg)
    end
  end

  def open(url)
    response = Net::HTTP.get(URI.parse(url))
    unless response.include?('404 Not Found') || response.to_s.empty?
      return response
    end
    nil
  end

  def positions(msg)
    race = ''

    open(SERVERLIST).each_line do |l|
      if l.strip.start_with?('race:')
        race = l.split("\"")[1]
      end
    end

    if msg.tail && PREVIOUS_RACES.include?(msg.tail.gsub(/\s+/, ''))
      race = msg.tail.gsub(/\s+/, '')
    end

    url = "http://www.formula1.com/sp/static/f1/2016/live/#{race}/Race/all.js"
    url_live = "https://lb.softpauer.com/f1/2016/live/#{race}/Race/all.js"

    drivers = []

    timing = open(url_live) || open(url)

    timing.each_line do |l|
      if l.start_with?("SP._input_('f'")
        l.split('[')[1].split(']')[0].split("{\"F\":\"")[1..-1].each do |d|
          i = d.split(",\"}")[0].split(',')
          drivers.push("#{i[3]} #{i[0]}")
        end
      end
    end

    msg.reply("#{race} positions: #{drivers.sort_by!{ |i| i.split(' ')[0].to_i }.join(', ')}")
  end

  def calendar(msg)
    page = Nokogiri::HTML(open('https://www.f1calendar.com/'))

    weekend = page.css('tbody.next-event').css('span.location')[0].inner_html.strip
    fp1 = Time.iso8601(page.css('tbody.next-event').css('tr.first-practice').css('abbr.dtstart').attribute('title')).utc
    fp2 = Time.iso8601(page.css('tbody.next-event').css('tr.second-practice').css('abbr.dtstart').attribute('title')).utc
    fp3 = Time.iso8601(page.css('tbody.next-event').css('tr.third-practice').css('abbr.dtstart').attribute('title')).utc
    q = Time.iso8601(page.css('tbody.next-event').css('tr.qualifying').css('abbr.dtstart').attribute('title')).utc
    r = Time.iso8601(page.css('tbody.next-event').css('tr.race').css('abbr.dtstart').attribute('title')).utc

    msg.reply("#{weekend} FP1: #{fp1} FP2: #{fp2} FP3: #{fp3} Q: #{q} R: #{r}")
  end
end
