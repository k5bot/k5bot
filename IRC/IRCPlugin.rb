# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPlugin is the superclass of all plugins

class IRCPlugin < IRCListener
	# Returns the root dir of the plugin
	def plugin_root
		"IRC/plugins/#{name}"
	end

	# Returns the name of the plugin
	def name
		self.class.to_s
	end

	# Returns a short description of the plugin
	def describe
	end

	# Returns a hash with available commands and their descriptions
	def commands
	end

	# Returns a hash with the names of all plugins this plugin depends on
	def self.dependencies
	end
end
