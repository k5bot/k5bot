# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Menu plugin

require 'yaml'
require_relative '../../IRCPlugin'
require_relative 'MenuState'
require_relative 'MenuNode'

class Menu < IRCPlugin
  Description = "Provides Menu-related functionality."
  Commands = {
    :n => 'returns the next list of entries',
    :u => 'goes up in hierarchy of entries'
  }

  def afterLoad
    @menu_states = {}

    begin
      Object.send :remove_const, :MenuState
      load "#{plugin_root}/MenuState.rb"
    rescue ScriptError, StandardError => e
      puts "Cannot load MenuState: #{e}"
    end

    begin
      Object.send :remove_const, :MenuNode
      load "#{plugin_root}/MenuNode.rb"
    rescue ScriptError, StandardError => e
      puts "Cannot load MenuNode: #{e}"
    end
  end

  def beforeUnload
    @menu_states = nil
  end

  def on_privmsg(msg)
    self.evict_expired_menus!
    return unless msg.tail
    case msg.botcommand
      when :n
        menu_state = @menu_states[msg.replyTo]
        return unless menu_state
        menu_state.show_descriptions!(msg)
      when :u
        menu_state = @menu_states[msg.replyTo]
        return unless menu_state
        menu_state.show_descriptions!(msg) if menu_state.move_up!()
      else
        menu_state = @menu_states[msg.replyTo]
        return unless menu_state
        index_str = msg.message[/^\s*[0-9]+\s*$/]
        index = 0
        index = index_str.to_i if index_str
        menu_state.show_descriptions! (msg) if menu_state.move_down_to!(menu_state.get_child(index))
    end
  end

  def put_new_menu(plugin, root_node, msg, menu_size = 12, expire_duration = 1920)
    menu_state = MenuState.new(plugin, menu_size, expire_duration)
    if menu_state.move_down_to!(root_node)
      menu_state.show_descriptions! (msg)
      @menu_states[reply_to] = menu_state
    end
  end

  def evict_plugin_menus!(plugin)
    @menu_states.reject! { |k, v| v.plugin == plugin }
  end

  def evict_expired_menus!
    @menu_states.reject! { |k, v| v.is_expired? }
  end
end
