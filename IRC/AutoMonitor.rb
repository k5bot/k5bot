# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Object wrapper that synchronizes all method calls to wrapped object

require 'monitor'

class AutoMonitor
  include MonitorMixin

  def initialize(obj)
    mon_initialize
    @obj = obj
  end

  def method_missing(sym, *args, &block)
    synchronize do
      @obj.send(sym, *args, &block)
    end
  end
end