# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCChannel describes an IRC channel

class IRCBot
class IRCChannel
  attr_accessor :name, :topic

  def initialize(name, topic=nil)
    @name, @topic = name, topic
  end
end
end