# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'time'

class URL < IRCPlugin
  Description = "Implements URL preview"

  def initialize(manager, config)
    super

    # HACK: avoid warnings about uninitialized variable @body_exist in fetch_by_uri()
    @body_exist = nil
  end

  def on_privmsg(msg)
    return if msg.botcommand # Don't react to url-s in commands

    text = msg.tail
    return unless text

    uris = URI.extract(text)

    uris.each do |uri|
      # Silently skip anything not starting with that,
      # b/c URI.extract() tends to accept anything with colon in it
      # (e.g. "nick:"), which then causes URI.parse() to fail with InvalidURIError
      next unless uri.start_with?("http://", "https://")

      handle_uri(uri, msg)
    end
  end

  USER_AGENT="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; WOW64; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET"
  ACCEPT_LANGUAGE="en, ja, *"

  def handle_uri(uri, msg)
    fetch_by_uri(uri) do |result|
      unless result.is_a?(Net::HTTPSuccess)
        begin
        result.error!
        rescue => e
          msg.reply(e.to_s)
          raise e
        end
      end

      content_type = result.content_type
      opts = result.type_params

      if content_type.eql?('text/html')
        return if result.body == nil || result.body.empty?

        doc = nil
        detected_encoding = opts['charset']

        unless detected_encoding
          # Fix encoding errors
          # Parse once to detect encoding from html
          doc = Nokogiri::HTML result.body
          detected_encoding = doc.encoding
        end

        if detected_encoding
          filtered = fix_encoding(result.body, detected_encoding)
          doc = Nokogiri::HTML filtered
        end

        title = doc.css('title')[0].text.chomp

        title.gsub!("[ \t\n\f\r]+", " ")

        msg.reply("Title: #{title}")
      else
        response = []

        response << "Type: #{content_type}" if content_type

        content_length = result['content-length']

        response << "Size: #{format_size(content_length.to_i)}" if content_length

        last_modified = result['last-modified']

        response << format_last_modified(last_modified) if last_modified

        msg.reply(response.join("; "))
      end
    end
  end


  def format_size(size)
    return sprintf("%.2fB", size) if size < 1024
    size /= 1024.0
    return sprintf("%.2fKiB", size) if size < 1024
    size /= 1024.0
    return sprintf("%.2fMiB", size) if size < 1024
    size /= 1024.0
    sprintf("%.2fGiB", size)
  end

  def format_last_modified(last_modified)
    elapsed = Time.now - Time.parse(last_modified)
    if elapsed < 0
      "Updated by time traveller in: #{last_modified}"
    else
      "Updated: #{format_time_offset(elapsed)} ago (#{last_modified})"
    end
  end

  def format_time_offset(time_in_sec)
    time_in_sec = time_in_sec.abs

    seconds = (time_in_sec % 60).to_i
    time_in_sec /= 60.0
    minutes = (time_in_sec % 60).to_i
    time_in_sec /= 60.0
    hours = (time_in_sec % 24).to_i
    time_in_sec /= 24.0
    days = time_in_sec.to_i

    if days > 0
      "#{days}d #{hours}h #{minutes}m #{seconds}s"
    elsif hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  # TODO: maybe use open-uri lib.
  def fetch_by_uri(uri, limit = 10, redirects = [], &block)
    throw ArgumentError, "Must be given receiving block" unless block_given?

    uri = URI.parse(uri)

    case uri.scheme
      when 'http'
        opts = {}
      when 'https'
        opts = {:use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE}
      else
        raise ArgumentError, "Unsupported URI scheme #{uri.scheme}"
    end

    request = Net::HTTP::Get.new(uri.request_uri,
                                 {
                                     'User-Agent' => USER_AGENT,
                                     'Accept-Language' => ACCEPT_LANGUAGE
                                 })

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 3
    http.use_ssl = opts[:use_ssl]
    http.verify_mode = opts[:verify_mode]

    response = http.start do
      http.request(request) do |res|
        # handle redirection outside, after closing current connection
        unless res.is_a?(Net::HTTPRedirection)
          yield res
          # HACK: prevent body from loading upon exiting request,
          # if it wasn't loaded already in yielded block.
          # @see HTTP.reading_body.
          res.instance_eval { @body_exist = false }
        end
      end
    end

    case response
      when Net::HTTPRedirection
        if (redirects.size >= limit) || (redirects.include? uri.to_s)
          raise ArgumentError, 'HTTP redirect too deep'
        end
        redirects << uri.to_s
        fetch_by_uri(response['location'], limit, redirects, &block)
      else
        response
    end
  end

  def fix_encoding(str, encoding)
    str.force_encoding encoding
    str.chars.collect do |c|
      (c.valid_encoding?) ? c:'?'
    end.join
  end
end
