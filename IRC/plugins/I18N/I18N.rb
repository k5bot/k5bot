# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Internationalization plugin

require 'rubygems'
require 'bundler/setup'
require 'i18n'

require 'IRC/IRCPlugin'

class I18N
  include IRCPlugin
  DESCRIPTION = 'Internationalization plugin.'
  COMMANDS = {
      :i18n_reload => 'reloads i18n translation files',
      :i18n_set => 'set i18n locale',
  }
  DEPENDENCIES = [:Router]

  def on_privmsg(msg)
    dispatch_message_by_command(msg, COMMANDS.keys) do
      check_and_complain(@plugin_manager.plugins[:Router], msg, :can_do_everything)
    end
  end

  def cmd_i18n_reload(msg)
    I18n.load_path = Dir[File.join(File.dirname(__FILE__), 'locales', '*.yml')]
    I18n.backend.load_translations
    msg.reply("Reloaded translations. Available locales: #{format_available_locales}")
  end

  def cmd_i18n_set(msg)
    new_locale = msg.tail && msg.tail.to_sym
    unless I18n::available_locales.include?(new_locale)
      msg.reply("Unknown locale. Available locales: #{format_available_locales}")
      return
    end

    msg.reply("Changed I18n locale to #{new_locale}. Previous locale: #{I18n.locale || I18n.default_locale}")
    I18n.locale = I18n.default_locale = new_locale
  end

  def format_available_locales
    I18n::available_locales.map(&:to_s).join(', ')
  end

  private

  def check_and_complain(checker, msg, permission)
    if checker.check_permission(permission, msg_to_principal(msg))
      true
    else
      msg.reply("Sorry, you don't have '#{permission}' permission.")
      false
    end
  end

  def msg_to_principal(msg)
    msg.principals.first
  end
end
