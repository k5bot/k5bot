# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Auth plugin provides functions for authentication and authorization

require 'base64'
require 'digest/sha2'

require_relative '../../IRCPlugin'

class Auth < IRCPlugin
  Description = 'Auth plugin provides functions for authentication and authorization'

  USAGE_PERMISSION = :can_register_credentials

  ACCESS_TIMESTAMP_KEY = :t
  ACCESS_PRINCIPAL_KEY = :p
  ACCESS_FORMER_PRINCIPAL_KEY = :w

  COMMAND_REGISTER = :cred_reg
  COMMAND_UNREGISTER = :cred_unreg

  Commands = {
      COMMAND_REGISTER => 'associates given credentials with the current IRC user.',
      COMMAND_UNREGISTER => 'disassociates given credentials from the current IRC user.',
  }

  Dependencies = [ :StorageYAML, :Router ]

  def afterLoad
    @router = @plugin_manager.plugins[:Router]

    @storage = @plugin_manager.plugins[:StorageYAML]
    @credentials_storage = @storage.read('dcc_access') || {}
  end

  def beforeUnload
    @credentials_storage = nil
    @storage = nil

    @router = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
      when COMMAND_REGISTER
        unless check_permission(USAGE_PERMISSION, msg_to_principal(msg))
          msg.reply("Sorry, you don't have '#{USAGE_PERMISSION}' permission.")
          return
        end

        tail = msg.tail
        return unless tail

        principal = msg_to_principal(msg)
        credentials = tail.split

        credentials.each do |cred|
          if @credentials_storage.include?(cred)
            if @credentials_storage[cred][ACCESS_PRINCIPAL_KEY]
              msg.reply("Credential is already assigned to #{@credentials_storage[cred][ACCESS_PRINCIPAL_KEY]}; Delete it first, using .#{COMMAND_UNREGISTER} #{cred}")
            else
              @credentials_storage[cred] = {ACCESS_PRINCIPAL_KEY => principal, ACCESS_TIMESTAMP_KEY => Time.now.utc.to_i}
              msg.reply("Associated you with credential: #{cred}")
            end
          else
            # Credential should be touched by actual attempt to connect first,
            # To prevent database pollution with random credentials.
            msg.reply("Unknown or invalid credential: #{cred}")
          end
        end

        store
      when COMMAND_UNREGISTER
        unless check_permission(USAGE_PERMISSION, msg_to_principal(msg))
          msg.reply("Sorry, you don't have '#{USAGE_PERMISSION}' permission.")
          return
        end

        tail = msg.tail
        return unless tail

        allowed_credentials, allowed_principals = [msg.credentials, msg.principals]

        credentials = tail.split

        credentials.each do |cred|
          ok = @credentials_storage.include?(cred)
          ok &&= allowed_credentials.include?(cred) || allowed_principals.include?(@credentials_storage[cred][ACCESS_PRINCIPAL_KEY])
          if ok
            was = @credentials_storage[cred].delete(ACCESS_PRINCIPAL_KEY)
            if was
              @credentials_storage[cred][ACCESS_FORMER_PRINCIPAL_KEY] = was
              msg.reply("Disassociated credential: #{cred}")
            else
              msg.reply("Credential isn't associated: #{cred}")
            end
          else
            msg.reply("Unknown, invalid or not your credential: #{cred}"  )
          end
        end

        store
    end
  end

  def get_principal_by_credential(credential)
    result = @credentials_storage[credential]

    unless result
      # Mark the first attempt to auth with these credentials
      result = @credentials_storage[credential] = {ACCESS_TIMESTAMP_KEY => Time.now.utc.to_i}
      store
    end

    result[ACCESS_PRINCIPAL_KEY]
  end

  def check_permission(permission, credential)
    # temporary fallback to auth via Router
    @router.check_permission(permission, credential)
  end

  def hash_credential(key)
    # TODO: ensure that all plugins hash their credentials
    # with this function, before using them.
    # This can be done e.g. by wrapping resulting string into Credential class and
    # checking instanceof() in all other functions.

    salt = (@config[:salt] || 'lame ass salt for those who did not set it themselves')
    Base64.strict_encode64(Digest::SHA2.digest(key.to_s + salt))
  end

  private

  def msg_to_principal(msg)
    msg.principals.first
  end

  def store
    @storage.write('dcc_access', @credentials_storage)
  end
end
