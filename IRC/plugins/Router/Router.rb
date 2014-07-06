# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Router plugin routes IRCMessage-s between plugins

require_relative '../../IRCPlugin'

class Router < IRCPlugin

  ALLOW_COMMAND = :unban
  DENY_COMMAND = :ban
  LIST_COMMAND = :show
  TEST_COMMAND = :test
  OP_COMMAND = :op
  DEOP_COMMAND = :deop

  META_ADD_COMMAND = :add
  META_DEL_COMMAND = :del

  Description = 'Provides inter-plugin message delivery and filtering.'

  Dependencies = [:StorageYAML]

  PRIVATE_RESTRICTION_DISCLAIMER = 'This command works only in private and only for bot operators'
  RESTRICTION_DISCLAIMER = 'This command works only for bot operators'

  Commands = {
      :acl => {
          nil => 'Bot access list and routing commands',
          DENY_COMMAND => "denies access to the bot to any user, whose 'nick!ident@host' matches given mask. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          ALLOW_COMMAND => "removes existing ban rule or adds ban exception. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          LIST_COMMAND => "shows currently effective access list. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          TEST_COMMAND => "matches given 'nick!ident@host' against access lists. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          META_ADD_COMMAND => "adds to a given access list a given mask. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          META_DEL_COMMAND => "deletes from a given access list a given mask. #{PRIVATE_RESTRICTION_DISCLAIMER}",
          OP_COMMAND => "applies +o to calling user on current channel. #{RESTRICTION_DISCLAIMER}",
          DEOP_COMMAND => "applies -o to calling user on current channel. #{RESTRICTION_DISCLAIMER}",
      }
  }

  def afterLoad
    @storage = @plugin_manager.plugins[:StorageYAML]

    @rules = @storage.read('router') || {}

    parse_rules()
  end

  def beforeUnload
    @compiled_rules = nil

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
    regexp.gsub!(/\*+/) do |_|
      '.*'
    end

    regexp
  end

  def to_regex(arr)
    regexp_join = arr.map { |x| from_simple_regexp(x) }.join(')|(?:')
    Regexp.new("^(?:#{regexp_join})$") if arr
  end

  def compile_rules(rules)
    result = rules.each_pair.map do |list_name, user_masks|
      [list_name, to_regex(user_masks)]
    end

    #noinspection RubyHashKeysTypesInspection
    Hash[result]
  end

  def parse_rules
    rules = @rules.merge({:can_do_everything => @config[:owners] || []}) do |_, old_v, new_v|
      old_v | new_v
    end
    @compiled_rules = compile_rules(rules)
  end

  def store_rules
    @storage.write('router', @rules)
  end

  def on_privmsg(msg)
    return unless msg.bot_command == :acl
    return unless check_is_op(msg.prefix)
    tail = msg.tail

    return unless tail
    command, tail = tail.split(/\s+/, 2)
    command.downcase!
    command = command.to_sym

    case command
    when OP_COMMAND
      if msg.private?
        msg.reply('Call this command in the channel where you want it to take effect.')
      else
        msg.bot.send_raw("CHANSERV OP #{msg.channelname} #{msg.nick}")
      end
      return
    when DEOP_COMMAND
      if msg.private?
        msg.reply('Call this command in the channel where you want it to take effect.')
      else
        msg.bot.send_raw("CHANSERV DEOP #{msg.channelname} #{msg.nick}")
      end
      return
    end

    return unless msg.private?

    if command == LIST_COMMAND
      @rules.each_pair.sort.map do |list_name, user_masks|
        msg.reply("#{list_name.to_s.capitalize}: #{user_masks.join(' | ')}")
      end
      return
    end

    return unless tail

    case command
    when DENY_COMMAND
      add_to_list(:bans, tail)

      if remove_from_list(:excludes, tail)
        msg.reply("Found ban exclusion rule for #{tail}. Removed it and added ban rule instead. To unban, use #{msg.command_prefix}acl #{ALLOW_COMMAND} #{tail}")
      else
        msg.reply("Added ban rule for #{tail}. To unban, use #{msg.command_prefix}acl #{ALLOW_COMMAND} #{tail}")
      end
    when ALLOW_COMMAND
      if remove_from_list(:bans, tail)
        msg.reply("Found ban rule for #{tail}. Removed it without adding an exclusion rule. Repeat this command to add an exclusion rule.")
      else
        add_to_list(:excludes, tail)
        msg.reply("Didn't find ban rule for #{tail}. Added an exclusion rule. To remove it, use #{msg.command_prefix}acl #{DENY_COMMAND} #{tail}")
      end
    when META_ADD_COMMAND
      list_name, user_mask = tail.split(/\s+/, 2)
      return unless user_mask
      list_name = normalize(list_name)
      unless can_alter_list(list_name, msg.prefix)
        msg.reply("I'm sorry, Dave. I'm afraid, you can't alter #{list_name} list.")
        return
      end
      add_to_list(list_name, user_mask)
      msg.reply("Added #{user_mask} into #{list_name} list. To remove, use #{msg.command_prefix}acl #{META_DEL_COMMAND} #{list_name} #{user_mask}")
    when META_DEL_COMMAND
      list_name, user_mask = tail.split(/\s+/, 2)
      return unless user_mask
      list_name = normalize(list_name)
      unless can_alter_list(list_name, msg.prefix)
        msg.reply("I'm sorry, Dave. I'm afraid, you can't alter #{list_name} list.")
        return
      end
      if remove_from_list(list_name, user_mask)
        msg.reply("Removed #{user_mask} from #{list_name} list. To re-add, use #{msg.command_prefix}acl #{META_ADD_COMMAND} #{list_name} #{user_mask}")
      else
        msg.reply("Didn't find #{user_mask} in #{list_name}.")
      end
    when TEST_COMMAND
      reply = @rules.keys.map do |ln|
        "#{ln.to_s.capitalize}: #{!!check_is_in_list(ln, tail)}"
      end.join('; ')
      msg.reply(reply)
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

  # externally used generic-purpose permission checking API
  def check_permission(permission, credential)
    !!check_is_in_list(normalize(permission), credential)
  end

  protected

  def normalize(list_name)
    list_name.to_s.downcase
  end

  def message_listeners(additional_listeners)
    additional_listeners + @plugin_manager.plugins.values
  end

  def check_is_in_list(list_name, credential)
    list = @compiled_rules[list_name.to_sym]
    list && credential && list.match(credential)
  end

  def can_alter_list(list_name, prefix)
    check_is_in_list("can_alter_#{list_name}", prefix) ||
        check_is_in_list(:can_do_everything, prefix)
  end

  def add_to_list(list_name, mask)
    list_name = list_name.to_sym
    @rules[list_name] ||= []
    @rules[list_name] |= [mask]
  end

  def remove_from_list(list_name, mask)
    list_name = list_name.to_sym
    rules_list = @rules[list_name]

    if rules_list && !rules_list.empty?
      rules_list.delete(mask)
    else
      @rules.delete(list_name)
      nil
    end
  end

  def check_is_banned(credential)
    check_is_in_list(:bans, credential)
  end

  def check_is_op(credential)
    check_is_in_list(:ops, credential) ||
      check_is_in_list(:can_do_everything, credential)
  end

  def check_is_excluded(credential)
    check_is_in_list(:excludes, credential)
  end

  def filter_message_global(message)
    return nil unless message.can_reply?  # Only filter messages
    # Ban by mask, if not in ban exclusion list and not an op.
    prefix = message.prefix
    check_is_banned(prefix) && !(check_is_excluded(prefix) || check_is_op(prefix))
  end

  def filter_message_per_listener(listener, message)
    return nil unless message.command == :privmsg # Only filter messages

    filter_hash = @config[:channels]
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

module BotCore::Listener
  def listener_priority
    0
  end
end
