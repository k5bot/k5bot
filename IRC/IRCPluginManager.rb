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

  def parse_config_entry(p)
    if p.is_a?(Hash)
      name = p.keys.first
      config = p[name]
    else
      name = p
      config = nil
    end
    return name, config
  end

  def load_plugins(plugins)
    return unless plugins
    @loading = plugins
    plugins.each do |p|
      name, config = parse_config_entry(p)
      load_plugin(name, config, false)
    end
    plugins.each do |p|
      name, _ = parse_config_entry(p)
      if plugin = @plugins[name.to_sym]
        print "Initializing #{name}..."
        plugin.afterLoad
        puts "done."
      end
    end
    @loading = nil
  end


  def unload_plugin(name)
    begin
      p = @plugins[name.to_sym]
      return false unless p

      dependants = []
      @plugins.keys.each do |suspectName|
        pluginClass = Kernel.const_get(suspectName.to_sym)
        dependants << suspectName if pluginClass::Dependencies and pluginClass::Dependencies.include? name.to_sym
      end
      if not dependants.empty?
        puts "Cannot unload plugin '#{name}', the following plugins depend on it: #{dependants.join(', ')}"
        return false
      end

      error = p.beforeUnload
      if error
        puts "'#{name}' refuses to unload: #{error}"
        return false
      end

      p.commands.keys.each{|c| @commands.delete c} if p.commands
      @plugins.delete name.to_sym
      @bot.router.unregister p
      Object.send :remove_const, name.to_sym
    rescue => e
      puts "Cannot unload plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}"
      return false
    end
    true
  end

  def load_plugin(name, config, callAfterLoad = true)
    return if name !~ /\A[a-zA-Z0-9]+\Z/m
    begin
      requested = "IRC/plugins/#{name.to_s}/#{name.to_s}.rb"
      filename = Dir.glob(requested, File::FNM_CASEFOLD).first
      unless requested.eql? filename
        puts "Cannot find plugin '#{name.to_s}'."
        return false
      end

      load filename
      pluginClass = Kernel.const_get(name.to_sym)
      if pluginClass::Dependencies
        lacking = []
        pluginClass::Dependencies.each do |d|
          lacking << d unless (@plugins[d]) || (@loading && @loading.include?(d))
        end
        unless lacking.empty?
          Object.send(:remove_const, name.to_sym) unless @plugins[name.to_sym]
          return false
        end
      end

      print "Loading #{name}..."
      p = @plugins[name.to_sym] = pluginClass.new(@bot)
      p.config = (config || {}).freeze
      p.commands.keys.each{|c| @commands[c] = p} if p.commands
      p.afterLoad if callAfterLoad
      puts "done."
    rescue ScriptError, StandardError => e
      puts "Cannot load plugin '#{name}': #{e}"
      return false
    end
    true
  end
end
