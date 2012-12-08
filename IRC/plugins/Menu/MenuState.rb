# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# MenuState contains per-user state of menu_text.

class MenuState

  # The plugin, to which the menu_text hierarchy belongs.
  attr_reader :plugin

  # The size of the menu_text chunks, in number of items, to display per
  # message.
  attr_reader :menu_size

  # The duration in seconds since last access, after which the entry is
  # considered expired.
  attr_reader :expiry_duration

  # Stack array of entered nodes, in parent -> child order. Rightmost node is
  # the current one.
  attr_reader :location

  # A mark of last output item description, or null, if everything was shown.
  attr_accessor :mark

  # The children items of the current node.
  attr_accessor :items

  # Last access time
  attr_accessor :access_time

  def initialize(plugin, menu_size, expiry_duration)
    @plugin = plugin
    @menu_size = menu_size
    @expiry_duration = expiry_duration
    @access_time = Time.now.to_i
    @items = nil
    @mark = nil
    @location = []
  end

  def is_expired?()
    Time.now.to_i > @access_time + @expiry_duration
  end

  def do_access!()
    @access_time = Time.now.to_i
  end

  def get_child(index)
    return nil unless items and index > 0 and index < items.length + 1
    items[index - 1]
  end

  def move_down_to!(node, msg)
    return false unless node # get_child failed or something

    self.do_access!

    new_items = node.enter(nil, msg)
    unless new_items
      # do nothing else if node is not enterable
      return false
    end
    if new_items.empty?
      # if node is enterable but empty,
      # print that there's nothing to look at, and don't enter
      msg.reply(node.description ? "No hits for #{node.description}." : "No hits.")
      return false
    end

    @location << node

    old_items = @items
    @items = new_items

    old_mark = @mark
    @mark = 0

    if new_items.length == 1
      unless self.move_down_to!(new_items[0], msg)
        # the single entry was a chain (no forks),
        # can't stay in it, rollback entering.
        if @location.size > 1
          @location.pop
          @items = old_items
          @mark = old_mark
        end
        return false
      end
      return true
    end

    #finally, a fork! print choices and remain there
    self.show_descriptions!(msg)

    true
  end

  def show_descriptions!(msg)
    self.do_access!

    unless @mark
      msg.reply("No more hits.")
      @mark = 0 # continue showing menu from the beginning
      return
    end

    menu_text = @items[@mark, @menu_size].map.with_index do |e, i|
      "#{i + @mark + 1} #{e.description}"
    end.join(' | ')

    menu_text = "#{@items.length} hits: " + menu_text if mark == 0

    @mark += @menu_size

    if @mark < @items.length
      menu_text += " [#{IRCMessage::BotCommandPrefix}n for next]"
    else
      @mark = nil
    end

    if @location.size > 1
      menu_text += " [#{IRCMessage::BotCommandPrefix}u to go up]"
    end

    msg.reply(menu_text)
  end

  def move_up!(msg)
    self.do_access!

    # don't allow to pop higher than topmost node
    unless @location.size > 1
      msg.reply("Can't move further up.")
      return false
    end

    child = @location.pop
    parent = @location[-1]

    # in case, if node is somehow no longer enterable
    @items = parent.enter(child, msg) || []

    @mark = 0

    self.show_descriptions!(msg)

    true
  end
end
