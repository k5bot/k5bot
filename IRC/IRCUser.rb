# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCUser describes an IRC user

class IRCUser
  attr_reader :name
  attr_accessor :realname, :host, :nick

  def initialize(ident=nil, host=nil, realname=nil, nick=nil)
    @host, @realname, @nick = host, realname, nick
    self.ident = ident
  end

  def ident=(ident)
    @ident = !(ident =~ /^~/)
    @name = IRCUser.ident_to_name(ident)
  end

  def ident
    name unless identified?
    "~#@name"
  end

  def identified?
    !!@ident
  end

  def host_mask
    "#@nick!#{ident}@#@host"
  end

  def self.ident_to_name(name)
    name.sub(/^~/, '') if name
  end
end
