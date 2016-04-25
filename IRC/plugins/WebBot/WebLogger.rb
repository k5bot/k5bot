# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# WebLogger is used instead of standard WEBrick logger,
# to log with our preferred format.

require 'monitor'

class WebBot
class WebLogger < WEBrick::BasicLog
  include MonitorMixin

  def log(level, data)
    self.synchronize do
      case level
        when FATAL, ERROR
          super(level, do_log(:error, data))
        else
          super(level, do_log(:log, data))
      end
    end
  end

  private

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def do_log(mode, text)
    "#{TIMESTAMP_MODE[mode]}WEB: #{Time.now}: #{text}"
  end
end
end