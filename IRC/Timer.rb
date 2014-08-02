# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'monitor'

class Timer
  def initialize(interval, &handler)
    raise ArgumentError, "Interval less than zero" if interval < 0
    extend MonitorMixin
    @handler = handler
    @interval = interval
    @deadline = nil
    @run = nil
    start
  end

  def start
    return if @run
    @run = true
    @th = Thread.new do
      push_back
      while run?
        to_sleep = synchronize do
          [@deadline - Time.now, 1].min
        end
        if to_sleep > 0
          sleep(to_sleep) rescue nil
        elsif run?
          @handler.call(self) rescue nil
          push_back
        end
      end
    end
  end

  def stop
    synchronize do
      @run = false
    end
    begin
      @th.join unless Thread.current.eql?(@th)
    rescue Interrupt
      # ignored
    end
  end

  def push_back
    synchronize do
      @deadline = Time.now + @interval
    end
  end

  private

  def run?
    synchronize do
      @run
    end
  end
end
