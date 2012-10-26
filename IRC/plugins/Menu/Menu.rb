# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Menu plugin

require 'yaml'
require_relative '../../IRCPlugin'
require_relative 'MenuState'
require_relative 'MenuNode'
require_relative 'MenuNodeSimple'

class Menu < IRCPlugin
  Description = "Provides Menu-related functionality."
  Commands = {
    :n => 'returns the next list of entries',
    :u => 'goes up in hierarchy of entries'
  }

  def afterLoad
    load_helper_class(:MenuState)
    load_helper_class(:MenuNode)
    load_helper_class(:MenuNodeSimple)

    @menu_states = {}
  end

  def beforeUnload
    @menu_states = nil

    unload_helper_class(:MenuNodeSimple)
    unload_helper_class(:MenuNode)
    unload_helper_class(:MenuState)

    nil
  end

  def on_privmsg(msg)
    self.evict_expired_menus!
    menu_state = @menu_states[msg.replyTo]
    return unless menu_state
    case msg.botcommand
      when :n
        menu_state.show_descriptions!(msg)
      when :u
        menu_state.move_up!(msg)
      else
        index_str = msg.message[/^\s*[0-9０１２３４５６７８９]+\s*$/]
        return unless index_str
        index_str.tr!('０１２３４５６７８９','0123456789')
        index = index_str.to_i
        menu_state.move_down_to!(menu_state.get_child(index), msg)
    end
  end

  def put_new_menu(plugin, root_node, msg, menu_size = 12, expire_duration = 1920)
    puts root_node.inspect
    menu_state = MenuState.new(plugin, menu_size, expire_duration)
    menu_state.move_down_to!(root_node, msg)
    @menu_states[msg.replyTo] = menu_state
  end

  def delete_menu(plugin, msg)
    @menu_states.delete(msg.replyTo)
  end

  def evict_plugin_menus!(plugin)
    @menu_states.reject! { |k, v| v.plugin == plugin }
  end

  def evict_expired_menus!
    @menu_states.reject! { |k, v| v.is_expired? }
  end
end
