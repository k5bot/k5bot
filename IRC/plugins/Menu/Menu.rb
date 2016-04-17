# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Menu plugin

require 'yaml'
require_relative '../../IRCPlugin'
require_relative '../../ContextMetadata'

require_relative 'MenuState'
require_relative 'MenuNode'
require_relative 'MenuNodeSimple'
require_relative 'MenuNodeText'
require_relative 'MenuNodeTextEnumerable'

class Menu < IRCPlugin
  DESCRIPTION = 'Provides Menu-related functionality.'
  Commands = {
    :n => "returns the next list of menu entries. Given a number, \
shows the list of entries starting from that position",
    :u => 'goes up in hierarchy of entries'
  }

  def afterLoad
    load_helper_class(:MenuState)
    load_helper_class(:MenuNode)
    load_helper_class(:MenuNodeSimple)
    load_helper_class(:MenuNodeText)
    load_helper_class(:MenuNodeTextEnumerable)
    load_helper_class(:MenuNodeTextRaw)

    @menu_states = {}
  end

  def beforeUnload
    @menu_states = nil

    unload_helper_class(:MenuNodeTextRaw)
    unload_helper_class(:MenuNodeTextEnumerable)
    unload_helper_class(:MenuNodeText)
    unload_helper_class(:MenuNodeSimple)
    unload_helper_class(:MenuNode)
    unload_helper_class(:MenuState)

    nil
  end

  def on_privmsg(msg)
    self.evict_expired_menus!
    menu_state = @menu_states[msg.context]
    return unless menu_state
    case msg.bot_command
      when :n
        index = Menu.get_int(msg.tail)
        menu_state.show_descriptions!(index, msg)
      when :u
        menu_state.move_up!(msg)
      when nil
        index = Menu.get_int(msg.tail)
        return unless index
        menu_state.move_down_to!(menu_state.get_child(index), msg)
    end
  end

  def put_new_menu(plugin, root_node, msg, menu_size = nil, expire_duration = 1920)
    unless menu_size
      menu_size = ContextMetadata.get_key(:menu_size) || 12
    end
    menu_state = MenuState.new(plugin, menu_size, expire_duration)
    put_new_menu_ex(menu_state, root_node, msg)
  end

  def put_new_menu_ex(menu_state, root_node, msg)
    menu_state.move_down_to!(root_node, msg)
    @menu_states[msg.context] = menu_state
  end

  def evict_plugin_menus!(plugin)
    @menu_states.reject! { |_, v| v.plugin == plugin }
  end

  def evict_expired_menus!
    @menu_states.reject! { |_, v| v.is_expired? }
  end

  private

  def self.get_int(s)
    return unless s
    index_str = s[/^\s*[0-9０１２３４５６７８９]+\s*$/]
    return unless index_str
    index_str.tr!('０１２３４５６７８９','0123456789')
    index_str.to_i
  end
end
