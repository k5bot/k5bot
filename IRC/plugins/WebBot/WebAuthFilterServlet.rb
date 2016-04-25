# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# HTTP Servlet for checking ContextMetadata for valid authentication before,
# delegating request to wrapped servlet.

require 'IRC/ContextMetadata'

class WebBot
class WebAuthFilterServlet < WEBrick::HTTPServlet::AbstractServlet
  WEB_USER_AUTH_KEY = :web_bot_user_auth

  def initialize(server, options)
    super

    @delegate = options[:Delegate]
    @delegate_options = options[:DelegateOptions]
    @unknown_delegate = options[:UnknownUserDelegate]
    @unauthorized_delegate = options[:UnauthorizedUserDelegate]
    @allow_unknown = options[:AllowUnknownUser]

    raise 'WebAuthFilterServlet configuration error' unless @delegate
  end

  def service(request, response)
    user_auth = ContextMetadata.get_key(WEB_USER_AUTH_KEY)

    # Copy user auth to request too
    request.user = user_auth

    unless user_auth
      do_log(:error, 'User auth not found in ContextMetadata')
      response.status = WEBrick::HTTPStatus::RC_INTERNAL_SERVER_ERROR
      return
    end

    unless @allow_unknown || !user_auth.authorizations.empty?
      do_log(:log, "Forbidding unknown user #{user_auth.caller_id}")
      deny(request, response, false, user_auth)
      return
    end

    unless user_auth.authorizations.any? { |_, is_authorized| is_authorized }
      do_log(:log, "Identified #{user_auth.caller_id} as non-authorized #{user_auth.principals}")
      deny(request, response, true, user_auth)
      return
    end

    delegate_instance = @delegate.get_instance(@server, *@delegate_options)
    delegate_instance.service(request, response)
  end

  def deny(request, response, user_known, user_auth)
    response.status = WEBrick::HTTPStatus::RC_FORBIDDEN

    delegate = user_known ? @unauthorized_delegate : @unknown_delegate

    delegate.service(request, response) if delegate
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def do_log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}#{self.class.name}: #{Time.now}: #{text}"
  end
end
end