# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Router plugin routes IRCMessage-s between plugins

require_relative '../../IRCPlugin'

class Router < IRCPlugin

  ALLOW_COMMAND = :acl_unban
  DENY_COMMAND = :acl_ban
  LIST_COMMAND = :acl_show
  TEST_COMMAND = :acl_test
  OP_COMMAND = :acl_op
  DEOP_COMMAND = :acl_deop

  Description = "Provides inter-plugin message delivery and filtering."

  Dependencies = [:StorageYAML]

  RESTRICTION_DISCLAIMER = "These commands only work in private and only for a restricted set of users"

  SUB_COMMANDS = {
      DENY_COMMAND => "denies access to the bot to any user, whose 'nick!ident@host' matches given mask",
      ALLOW_COMMAND => "removes existing ban rule or adds ban exception",
      LIST_COMMAND => "shows currently effective access list",
      TEST_COMMAND => "matches given 'nick!ident@host' against access lists",
  }

  Commands = {
      :acl => "- access list commands: #{SUB_COMMANDS.map { |k, v| "'.#{k}' #{v}."}.join(' ')} #{RESTRICTION_DISCLAIMER}"
  }

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @rules = @storage.read('router') || {}
    @rules[:ops] ||= []
    @rules[:bans] ||= []
    @rules[:excludes] ||= []

    parse_rules()
  end

  def beforeUnload
    @excludes = nil
    @bans = nil
    @ops = nil

    @rules = nil

    @storage = nil

    nil
  end

  def from_simple_regexp(regexp)
    # Only allow irc-style * for masks.
    # Replace all runs of other text with its escaped form
    regexp = regexp.dup
    regexp.gsub!(/[^*]+/) do |match|
      Regexp.quote(match)
    end
    # Replace runs of * with .*
    regexp.gsub!(/\*+/) do |match|
      '.*'
    end

    regexp
  end

  def to_regex(arr)
    regexp_join = arr.map { |x| from_simple_regexp(x) }.join(')|(?:')
    Regexp.new("^(?:#{regexp_join})$") if arr
  end

  def parse_rules()
    @ops = to_regex(@rules[:ops])
    @bans = to_regex(@rules[:bans])
    # ops are always excluded, to avoid accidental self-bans.
    @excludes = to_regex(@rules[:excludes] | @rules[:ops])
  end

  def store_rules
    @storage.write('router', @rules)
  end

  def on_privmsg(msg)
    return unless msg.botcommand
    return unless msg.private?
    return unless check_is_op(msg)
    tail = msg.tail

    case msg.botcommand
    when DENY_COMMAND
      return unless tail
      @rules[:bans] |= [tail]
      if @rules[:excludes].delete(tail)
        msg.reply("Found ban exclusion rule for #{tail}. Removed it and added ban rule instead. To unban, use #{msg.command_prefix}#{ALLOW_COMMAND} #{tail}")
      else
        msg.reply("Added ban rule for #{tail}. To unban, use #{msg.command_prefix}#{ALLOW_COMMAND} #{tail}")
      end
    when ALLOW_COMMAND
      return unless tail
      if @rules[:bans].delete(tail)
        msg.reply("Found ban rule for #{tail}. Removed it without adding an exclusion rule. Repeat this command to add an exclusion rule.")
      else
        @rules[:excludes] |= [tail]
        msg.reply("Didn't found ban rule for #{tail}. Added an exclusion rule. To remove it, use #{msg.command_prefix}#{DENY_COMMAND} #{tail}")
      end
    when OP_COMMAND
      return unless tail
      @rules[:ops] |= [tail]
      msg.reply("Added #{tail} to ops.")
    when DEOP_COMMAND
      return unless tail
      if @rules[:ops].delete(tail)
        msg.reply("Deopped #{tail}.")
      else
        msg.reply("There's no #{tail} among ops.")
      end
    when LIST_COMMAND
      msg.reply("Ops: #{@rules[:ops].join(' | ')}")
      msg.reply("Bans: #{@rules[:bans].join(' | ')}")
      msg.reply("Exludes: #{@rules[:excludes].join(' | ')}")
      return
    when TEST_COMMAND
      return unless tail
      msg.reply("Ops: #{!!check_is_op(tail)}; Bans: #{!!check_is_banned(tail)}; Exludes: #{!!check_is_excluded(tail)}")
      return
    else
      return
    end

    begin
      parse_rules
      store_rules
    rescue => e
      msg.reply("Failed to update rules: #{e}")
    end
  end

  # externally used broadcasting API
  def dispatch_message(msg, additional_listeners=[])

    return if filter_message_global(msg)

    message_listeners(additional_listeners).sort_by { |a| a.listener_priority }.each do |listener|
      begin
        next if filter_message_per_listener(listener, msg)
        result = listener.receive_message(msg)
        break if result # treat all non-nil results as request for stopping message propagation
      rescue Exception => e
        puts "Listener error: #{e}\n\t#{e.backtrace.join("\n\t")}"
      end
    end
  end

  def message_listeners(additional_listeners)
    additional_listeners + @plugin_manager.plugins.values
  end

  def check_is_banned(message)
    message = message.prefix unless message.instance_of?(String)
    @bans && @bans.match(message)
  end

  def check_is_op(message)
    message = message.prefix unless message.instance_of?(String)
    @ops && @ops.match(message)
  end

  def check_is_excluded(message)
    message = message.prefix unless message.instance_of?(String)
    @excludes && @excludes.match(message)
  end

  def filter_message_global(message)
    return nil unless message.command == :privmsg # Only filter messages
    # Ban by mask, if not in ban exclusion list.
    check_is_banned(message) && !check_is_excluded(message)
  end

  def filter_message_per_listener(listener, message)
    return nil unless message.command == :privmsg # Only filter messages

    filter_hash = @config
    return nil unless filter_hash # Filtering only if enabled in config
    return nil unless listener.is_a?(IRCPlugin) # Filtering only works for plugins
    allowed_channels = filter_hash[listener.name.to_sym]
    return nil unless allowed_channels # Don't filter plugins not in list
    # Private messages to our bot can be filtered by special :private symbol
    channel_name = message.channelname || :private
    result = allowed_channels[channel_name]
    # policy for not mentioned channels can be defined by special :otherwise symbol
    !(result != nil ? result : allowed_channels[:otherwise])
  end
end

module IRCListener
  def listener_priority
    0
  end
end
