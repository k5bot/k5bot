# encoding: utf-8
# Bitly plugin

require_relative '../../IRCPlugin'
require 'uri'
require 'net/http'

class Bitly < IRCPlugin
	Description = "Provides URL shortening services to other plugins."

	def shortenURL(url)
		user = 'j416'
		apiKey = 'R_66509fcbb9532926b4d501b021939dc8'
		return unless user && apiKey && url && !url.empty?
		requestURL = "http://api.bitly.com/v3/shorten?login=#{user}&apiKey=#{apiKey}&format=txt&longUrl=#{URI.escape(url)}"
		result = Net::HTTP.get(URI.parse(requestURL));
		return if [Net::HTTPSuccess, Net::HTTPRedirection].include? result
		case response
		when Net::HTTPSuccess
			response.strip
		when Net::HTTPRedirection
			fetch(response['location'], limit - 1).strip
		else
			nil
		end
	rescue => e
		puts "Cannot shorten URL: #{e}\n\t#{e.backtrace.join("\n\t")}"
	end

	def on_privmsg(msg)
		return unless msg.tail
		case msg.botcommand
		when :bitly
			msg.reply shortenURL(msg.tail)
		end
	end
end
