# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPlugin is the superclass of all plugins

class IRCPlugin < IRCListener
	# A short description of this plugin
	Description = nil

	# A hash with available commands and their descriptions
	Commands = nil

	# A hash containing the names of the plugins this plugin depends on
	Dependencies = nil

	# Returns the name of this plugin
	def name; self.class.name; end

	# Returns the root dir of this plugin
	def plugin_root; "IRC/plugins/#{name}"; end

	def description;  self.class::Description;  end
	def commands;     self.class::Commands;     end
	def dependencies; self.class::Dependencies; end
end
