# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Translate plugin

require_relative '../../IRCPlugin'
require_relative '../../Counter'
require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'time'
require 'json'

class URL < IRCPlugin
  Description = "Implements URL preview"
  Commands = {
      :short => "shortens a previously seen URL with goo.gl. This command can accept either index (1 is the most recent one) or substring of the desired URL",
  }

  def initialize(manager, config)
    super

    # HACK: avoid warnings about uninitialized variable @body_exist in fetch_by_uri()
    @body_exist = nil
  end


  def afterLoad
    @channel_queues = {}
    @url_cache = {}
    @url_counter = Counter.new()
  end

  def beforeUnload
    @url_counter = nil
    @url_cache = nil
    @channel_queues = nil
  end

  def on_privmsg(msg)
    case msg.botcommand
      when :short
        text = msg.tail
        url = get_uri_from_queue(msg.replyTo, text)
        if url
          short_url = shorten_url(url)
          msg.reply("Short URL: #{short_url} for URL: #{url.abbreviate(100)}") if short_url
        end
      when nil # Don't react to url-s in commands
        scan_for_uri(msg)
    end
  end

  def on_action(msg)
    scan_for_uri(msg)
  end

  def scan_for_uri(msg)
    text = msg.tail
    return unless text

    uris = URI.extract(text)

    uris.delete_if do |uri|
      # Silently skip anything not starting with that,
      # b/c URI.extract() tends to accept anything with colon in it
      # (e.g. "nick:"), which then causes URI.parse() to fail with InvalidURIError
      !uri.start_with?("http://", "https://")
    end

    # ')' is rarely an URI resource name so assume that the ')' in URIs
    # ending in '/)' is just an artifact from the URI having been
    # enclosed in parentheses that URI#extract didn't quite handle
    uris.each { |uri| uri.gsub!(/\/\)$/, '/') }

    put_uris_to_queue(msg.replyTo, uris)

    uris.each do |uri|
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

      if content_type.eql?('text/html')
        doc = html_to_nokogiri(result)
        return unless doc

        title = doc.css('title')[0].text.chomp

        title.gsub!(/[ \t\n\f\r]+/, ' ')
        title.strip!

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

  def html_to_nokogiri(result)
    return if result.body == nil || result.body.empty?

    # rescuing from stupid servers, which serve
    # parameters without names, e.g. "text/html;UTF-8"
    # which must be "text/html;charset=UTF-8" instead.
    opts = result.type_params rescue {}

    doc = nil
    detected_encoding = opts['charset']

    # If content-type has an unknown/misspelled encoding, get rid of it.
    detected_encoding = nil unless (Encoding.find(detected_encoding) rescue nil)

    unless detected_encoding
      # Fix encoding errors
      # Parse once to detect encoding from html

      # HACK: ensure, that body.encoding returns "ASCII-8BIT".
      # Sometimes it happens to be US-ASCII for some reason,
      # and that throws off nokogiri encoding detection.
      result.body.force_encoding('ASCII-8BIT')

      doc = Nokogiri::HTML result.body
      detected_encoding = doc.encoding
    end

    if detected_encoding
      filtered = fix_encoding(result.body, detected_encoding)
      doc = Nokogiri::HTML filtered
    end

    doc
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

    uri = URI.parse(uri) unless uri.is_a? URI

    request = Net::HTTP::Get.new(uri.request_uri,
                                 {
                                     'User-Agent' => USER_AGENT,
                                     'Accept-Language' => ACCEPT_LANGUAGE
                                 })

    http = get_http_by_uri(uri)

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

        new_uri = URI.parse(response['location'])
        if new_uri.relative?
          # Although it violates RFC2616, Location: field may have relative
          # URI.  It is converted to absolute URI using uri as a base URI.
          new_uri = uri.merge(new_uri)
        end

        fetch_by_uri(new_uri, limit, redirects, &block)
      else
        response
    end
  end

  def get_opts_by_uri(uri)
    case uri.scheme
      when 'http'
        opts = {}
      when 'https'
        opts = {:use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE}
      else
        raise ArgumentError, "Unsupported URI scheme #{uri.scheme}"
    end
    opts
  end

  def get_http_by_uri(uri)
    opts = get_opts_by_uri(uri)

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 3
    http.use_ssl = opts[:use_ssl]
    http.verify_mode = opts[:verify_mode]
    http
  end

  def fix_encoding(str, encoding)
    str.force_encoding encoding
    str.chars.collect do |c|
      (c.valid_encoding?) ? c:'?'
    end.join
  end

  SHORTENER_SERVICE_URL="https://www.googleapis.com/urlshortener/v1/url"
  SHORTENER_QUEUE_SIZE=10

  def put_uris_to_queue(queue_id, uris)
    queue = (@channel_queues[queue_id] ||= [])

    uris.each do |uri|
      queue << uri
      @url_counter.add(uri)
    end

    while queue.size > SHORTENER_QUEUE_SIZE
      uri = queue.shift
      @url_counter.remove(uri) { @url_cache.delete(uri) }
    end
  end

  def get_uri_from_queue(queue_id, text)
    queue = @channel_queues[queue_id]
    return unless queue

    index = text ? text.to_i : 1
    return queue[-index] if index > 0

    index = queue.rindex do |uri|
      uri.include?(text)
    end

    queue[index] if index
  end

  def shorten_url(url)
    short_url = @url_cache[url]
    short_url = @url_cache[url] = do_shorten_url(url) unless short_url
    short_url
  end

  def do_shorten_url(url)
    # Call shortener API
    uri = URI.parse(SHORTENER_SERVICE_URL)

    http = get_http_by_uri(uri)

    res = http.start do
      request = Net::HTTP::Post.new(uri.path)
      request["user-agent"] = USER_AGENT
      request["Accept"] = "application/json"
      request.body={:longUrl => url}.to_json
      request.content_type="application/json"

      http.request(request)
    end

    json = JSON.parse(res.body)

    json["id"] if json
  end
end

class String
  def abbreviate(len)
    return "#{self[0..len-4]}..." if self.size > len
    self
  end
end
