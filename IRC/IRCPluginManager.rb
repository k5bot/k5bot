# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPluginManager manages all plugins

class IRCPluginManager < IRCListener
	attr_reader :plugins, :commands

	def initialize(bot)
		super(bot)
		@plugins = {}
		@commands = {}
	end

	def loadPlugins(plugins)
		return unless plugins
		plugins.each do |plugin|
			begin
				load "IRC/plugins/#{plugin.to_s}.rb"
				p = @plugins[plugin.to_sym] = Kernel.const_get(plugin.to_sym).new(@bot)
				p.commands.keys.each{|c| @commands[c] = p} if p.commands
#			rescue Exception => e
#				puts "Cannot load plugin '#{plugin}': #{e}"
			end
		end
	end
end
