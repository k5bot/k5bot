# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Clock plugin tells the time

require 'rubygems'
require 'bundler/setup'
require 'tzinfo'

require_relative '../../IRCPlugin'

class Clock < IRCPlugin
  Description = "The Clock plugin tells the time."
  Commands = {
      :time => "tells the current time. \
Optionally accepts space-separated list of timezone identifiers (e.g. Asia/Tokyo), \
or simply their parts after / and without spaces (e.g. 'NewYork'), \
timezone abbreviations (e.g. UTC, JST), \
and ISO-3166 country names (e.g. US, JP)",
      :jtime => 'tells the current time in Japan only',
      :utime => 'tells the current time in UTC only'
  }

  def normalize_zone_identifier(id)
    id.upcase.gsub(/_/,'').gsub(/-(\D)/,'\1')
  end

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

    # Timezone.get() doesn't accept arbitrary case,
    # so let's compose our own case-insensitive table.
    @zone_by_identifier = {}
    @zone_by_city = {}

    TZInfo::Timezone.all.each do |zone|
      identifier = normalize_zone_identifier(zone.identifier)
      @zone_by_identifier.merge!(identifier => zone) do |key, old_val, new_val|
        raise "Can't disambiguate timezone #{key}: it's either #{old_val} or #{new_val}"
      end

      # The part after first slash.
      identifier.match(/^[^\/]+\/(.+)$/) do |m|
        @zone_by_city.merge!(m[1] => [zone]) do |key, old_val, new_val|
          old_val |= new_val
        end
      end
    end
  end

  def beforeUnload
    @zone_by_abbreviation = nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :time
      zones = (msg.tail || 'UTC JST').split
      time = Time.now
      msg.reply "#{time(time, zones)}"
    when :jtime
      time = Time.now
      msg.reply "#{time(time, %w(JST))}"
    when :utime
      time = Time.now
      msg.reply utime(time)
    when :new_year
      time = Time.now
      msg.reply(new_year_celebrators(time))
    end
  end

  def new_year_celebrators(time)
    time = Time.at(time).utc # convert time to UTC, or strftime won't work properly

    celebrating = TZInfo::Country.all.map do |country|
      has_new_year = country.zones.any? do |zone|
        '001 00'.eql?(zone.strftime('%j %H', time))
      end
      country.name if has_new_year
    end.reject(&:nil?)

    if celebrating.empty?
      'No countries celebrate at the moment'
    else
      celebrating.sort.join(',')
    end
  end

  def time(time, search_terms)
    time = Time.at(time).utc # convert time to UTC, or strftime won't work properly

    search_terms.map do |search_term|
      presorted = false

      # Try to search by abbreviation verbatim first.
      # Useful to differentiate e.g. 'MEST' vs 'MeST'.
      zones = @zone_by_abbreviation[search_term.to_sym]
      # If that didn't help, try upcase abbreviation.
      zones ||= @zone_by_abbreviation[search_term.upcase.to_sym]
      # Maybe it's a ISO 3166 country code, e.g. 'US'?
      unless zones
        zones = TZInfo::Country.get(search_term.upcase).zones rescue nil
        # Country.get() returns array ordered by relevancy descending.
        presorted = true if zones
      end
      # Maybe it's a zone identifier, e.g. 'America/New_York'?
      unless zones
        zones = @zone_by_identifier[normalize_zone_identifier(search_term)]
        zones = [zones] if zones
      end
      # Maybe it's a part of identifier after first slash, e.g. 'NewYork'?
      unless zones
        zones = @zone_by_city[normalize_zone_identifier(search_term)]
      end

      if zones
        # Zone abbreviations are actually ambiguous.
        # Let's try and group known zones by resulting times.
        zones.group_by do |zone|
          zone.strftime('%Y-%m-%d %H:%M:%S', time)
        end.map do |format, sub_zones|
          best_zone = if presorted
                        # group_by() preserved desired order, the best one is the first.
                        sub_zones[0]
                      else
                        # otherwise, find the one with the shortest identifier.
                        sub_zones.min_by { |z| z.identifier.size }
                      end

          abbrev = best_zone.strftime('%Z', time)
          identifier = best_zone.identifier
          "#{format} #{abbrev}(#{identifier}#{',...' if sub_zones.size>1})"
        end.sort.join('; ')
      else
        "Unknown timezone '#{search_term}'"
      end
    end.join(' | ')
  end

  def utime(t)
    Time.at(t).utc
  end
end
