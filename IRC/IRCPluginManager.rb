# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPluginManager manages all plugins

class IRCPluginManager < IRCListener
	attr_reader :plugins, :commands

	def initialize(bot)
		super
		@plugins = {}
		@commands = {}
	end

	def loadPlugins(plugins)
		@loading = plugins
		plugins.each{|name| loadPlugin(name, false)} if plugins
		plugins.each do |name|
			if p = @plugins[name.to_sym]
				p.afterLoad
			end
		end
		@loading = nil
	end

	def unloadPlugin(name)
		begin
			if p = @plugins[name.to_sym]
				error = p.beforeUnload
				unless error
					p.commands.keys.each{|c| @commands.delete c} if p.commands
					@plugins.delete name.to_sym
					@bot.router.unregister p
					Object.send :remove_const, name.to_sym
					true
				else
					puts "'#{name}' refuses to unload: #{error}"
				end
			end
		rescue => e
			puts "Cannot unload plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}"
		end
	end

	def loadPlugin(name, callAfterLoad = true)
		return if name !~ /\A[a-zA-Z0-9]+\Z/m
		begin
			load "IRC/plugins/#{name.to_s}/#{name.to_s}.rb"
			pluginClass = Kernel.const_get(name.to_sym)
			if pluginClass::Dependencies
				lacking = []
				pluginClass::Dependencies.each do |d|
					lacking << d unless (@plugins[d]) || (@loading && @loading.include?(d))
				end
				unless lacking.empty?
					return false
				end
			end
			p = @plugins[name.to_sym] = pluginClass.new(@bot)
			p.commands.keys.each{|c| @commands[c] = p} if p.commands
			p.afterLoad if callAfterLoad
			true
		rescue ScriptError, StandardError => e
			puts "Cannot load plugin '#{name}': #{e}"
		end
	end
end
