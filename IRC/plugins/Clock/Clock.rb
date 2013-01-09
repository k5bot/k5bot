# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require 'rubygems'
require 'tzinfo'

require_relative '../../IRCPlugin'

class Clock < IRCPlugin
  Description = "The Clock plugin tells the time."
  Commands = {
      :time => 'tells the current time. Optionally accepts space-separated list of timezones',
      :jtime => 'tells the current time in Japan only',
      :utime => 'tells the current time in UTC only'
  }


  def afterLoad
    # Try to gather all known zone abbreviations
    @zone_by_abbreviation = {}

    # For this we'll try to get periods for several dates,
    # To catch daylight-saving and other abbreviation changes.
    now = Time.now.utc
    half_year = 60*60*24*366/2
    times = [now - half_year, now, now + half_year]

    TZInfo::Timezone.all_data_zones.each do |zone|
      periods = []

      times.each do |time|
        periods |= zone.periods_for_local(time)
      end

      periods.each do |period|
        abbrev = period.abbreviation
        @zone_by_abbreviation[abbrev] ||= []
        @zone_by_abbreviation[abbrev] |= [zone]
      end
    end
  end

  def beforeUnload
    @zone_by_abbreviation = nil
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :time
      zones = (msg.tail || 'UTC JST').split
      time = Time.now
      msg.reply "#{time(time, zones)}"
    when :jtime
      time = Time.now
      msg.reply jtime(time)
    when :utime
      time = Time.now
      msg.reply utime(time)
    end
  end

  def time(time, abbrevs)
    time = Time.at(time).utc # convert time to UTC, or strftime won't work properly

    abbrevs.map do |abbrev|
      abbrev.upcase!
      zones = @zone_by_abbreviation[abbrev.to_sym]

      if zones
        # Zone abbreviations are actually ambiguous.
        # Let's try and group known zones by resulting times.
        zones.group_by do |zone|
          zone.strftime('%Y-%m-%d %H:%M:%S %Z', time)
        end.map do |format, sub_zones|
          best_zone = sub_zones.map { |z| z.identifier }.min_by { |id| id.size }
          "#{format} (in #{best_zone}#{',...' if sub_zones.size>1})"
        end.sort.join(', ')
      else
        "Unknown timezone #{abbrev}"
      end
    end.join(' | ')
  end

  def utime(t)
    Time.at(t).utc
  end

  def jtime(t)
    Time.at(t).localtime("+09:00").strftime '%Y-%m-%d %H:%M:%S JST'
  end
end
