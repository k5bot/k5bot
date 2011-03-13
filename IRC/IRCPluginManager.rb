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
		@loading = plugins
		plugins.each{|name| loadPlugin name} if plugins
		@loading = nil
	end

	def unloadPlugin(name)
		begin
			if p = @plugins[name.to_sym]
				p.commands.keys.each{|c| @commands.delete c} if p.commands
				@plugins.delete name.to_sym
				@bot.router.unregister p
				Object.send :remove_const, name.to_sym
				true
			end
		rescue => e
			puts "Cannot unload plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}"
		end
	end

	def loadPlugin(name)
		return if name !~ /\A[a-zA-Z0-9]+\Z/m
		begin
			load "IRC/plugins/#{name.to_s}/#{name.to_s}.rb"
			p = @plugins[name.to_sym] = Kernel.const_get(name.to_sym).new(@bot)
			p.commands.keys.each{|c| @commands[c] = p} if p.commands
			true
		rescue ScriptError, StandardError => e
			puts "Cannot load plugin '#{name}': #{e}"
		end
	end
end
