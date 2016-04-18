# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Karma plugin

require 'IRC/IRCPlugin'

class Karma < IRCPlugin
  DESCRIPTION = 'Stores karma and other kinds of points for users.'

  DEPENDENCIES = [:NumberSpell, :StorageYAML]

  def afterLoad
    @ns = @plugin_manager.plugins[:NumberSpell]
    @storage = @plugin_manager.plugins[:StorageYAML]

    @karma = {}

    @config.each do |command, sub_config|
      @karma[command.to_sym] = @storage.read(sub_config[:file]) || {}

      # Replace regexp text with actual precompiled regexps
      sub_config[:matchers].each do |matcher|
        regexp = matcher[:regexp]
        next if regexp.is_a?(Regexp)
        # regexp.gsub!('#{sender}', msg.nick) # Maybe will be useful someday
        regexp.gsub!('#{receiver}', '([[[:ascii:]]&&\S]+)')
        matcher[:regexp] = Regexp.new(regexp)
      end
    end
  end

  def transaction(command)
    sub_store = @karma[command].dup
    result = yield sub_store
    @karma[command] = sub_store
    @storage.write(@config[command][:file], @karma[command])
    result
  end

  def commands
    Hash[@config.map do |command, config|
      [command, config[:help]]
    end]
  end

  def beforeUnload
    @karma = nil

    @storage = nil
    @ns = nil

    nil
  end

  def on_privmsg(msg)
    if msg.bot_command
      respond_to_query(msg)
    elsif !msg.private?
      respond_to_change(msg)
    end
  end

  def respond_to_query(msg)
    bot_command = msg.bot_command

    sub_config = @config[bot_command]
    return unless sub_config
    sub_store = @karma[bot_command]

    nick = msg.tail || msg.nick
    user = msg.bot.find_user_by_nick(nick)
    if user && user.uid
      points = sub_store[user.uid]
      if points
        reply_format = random_choice(sub_config[:query])
        msg.reply(template(reply_format, msg.nick, nil, user.nick, points))
      else
        reply_format = random_choice(sub_config[:query_fail])
        msg.reply(template(reply_format, msg.nick, nil, user.nick, nil))
      end
    else
      msg.reply('Cannot map this nick to a user at the moment, sorry.')
    end
  end

  def respond_to_change(msg)
    text = msg.tail || ''
    @config.each do |bot_command, sub_config|
      sub_config[:matchers].each do |matcher|

        success = transaction(bot_command) do |sub_store|
          matches_allowed = matcher[:multi] || 1
          replies = []

          text.scan(matcher[:regexp]) do
            # Gather actual MatchData instead of simply Strings.
            match = $~

            sender_user = msg.user

            receiver_nick = nil
            receiver_points = nil
            sender_points = nil

            if matcher[:receiver_delta]
              # if this kind of karma has receiver, his nick
              # must be matched by the first group of regexp
              receiver_nick = match[1]
              next unless receiver_nick

              receiver_user = msg.bot.find_user_by_nick(receiver_nick)
              # Disallow sender and receiver to be the same
              next unless receiver_user != sender_user

              receiver_points = change_user_points(sub_store, receiver_user, matcher[:receiver_delta])

              # Failed to update receiver points, stop
              next unless receiver_points
            end

            if matcher[:sender_delta]
              sender_points = change_user_points(sub_store, sender_user, matcher[:sender_delta])
              raise "Bug! Failed to update #{bot_command} points for #{msg.nick}" unless sender_points
            end

            reply_format = random_choice(matcher[:response])
            reply_msg = template(reply_format, msg.nick, sender_points, receiver_nick, receiver_points)

            replies << reply_msg

            # Limit the number of successful matches to check
            break unless replies.size < matches_allowed
          end

          # None of the matches were actually successful,
          # rollback transaction and try next matcher.
          break if replies.empty?

          replies.each do |reply_msg|
            msg.reply(reply_msg) if reply_msg
          end

          # Mark the transaction success
          true
        end

        # Don't process further matchers for this kind of karma
        break if success
      end
    end
  end

  def change_user_points(sub_store, user, delta)
    user_id = user && user.uid
    return unless user_id
    sub_store[user_id] = 0 unless sub_store[user_id]
    sub_store[user_id] += delta
  end

  def random_choice(arr)
    arr[rand(arr.size)] if arr && arr.size > 0
  end

  def template(format, sender, sender_points, receiver, receiver_points)
    return unless format
    format = format.dup

    format.gsub!('#{sender}', sender)
    if sender_points
      format.gsub!('#{sender_points}', sender_points.to_s)
      format.gsub!('#{sender_points_kanji}') do |m|
        @ns.spell(sender_points)
      end
    end

    format.gsub!('#{receiver}', receiver) if receiver
    if receiver_points
      format.gsub!('#{receiver_points}', receiver_points.to_s)
      format.gsub!('#{receiver_points_kanji}') do |m|
        @ns.spell(receiver_points)
      end
    end

    format
  end
end
