# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPluginManager manages all plugins

class IRCPluginManager < IRCListener
  attr_reader :plugins, :config

  def initialize(router, config)
    @plugins = {}
    @router = router
    @config = config

    @listeners = [] # IRCPluginListener-s of plugin attach/detach events
  end

  def register(listener)
    if listener && listener.attached_to_manager(self)
      @listeners << listener
    end
  end

  def unregister(listener)
    old_size = @listeners.size
    @listeners.delete_if{|l| l == listener}
    while old_size > @listeners.size
      listener.detached_from_manager(self)
      old_size -= 1
    end
  end

  def load_all_plugins()
    do_load_plugins(@config)
  end

  def load_plugin(name)
    config_entry = find_config_entry(name)

    do_load_plugins([config_entry])
  end

  def unload_plugin(name)
    unloading = [find_config_entry(name)]

    error = notify_listeners(:before_unload, unloading)
    if error
      puts "A PluginManager listener refuses unloading of plugins: #{error}"
      return false
    end

    begin
      p = @plugins[name.to_sym]
      return false unless p

      dependants = []
      @plugins.keys.each do |suspectName|
        pluginClass = Kernel.const_get(suspectName.to_sym)
        dependants << suspectName if pluginClass::Dependencies and pluginClass::Dependencies.include? name.to_sym
      end

      unless dependants.empty?
        puts "Cannot unload plugin '#{name}', the following plugins depend on it: #{dependants.join(', ')}"
        return false
      end

      error = p.beforeUnload
      if error
        puts "'#{name}' refuses to unload: #{error}"
        return false
      end

      @plugins.delete name.to_sym

      @router.unregister p

      unload_plugin_class(name)
    rescue => e
      puts "Cannot unload plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}"
      return false
    ensure
      notify_listeners(:after_unload, unloading)
    end

    true
  end

  private

  def find_config_entry(name)
    name = name.to_sym

    config_entry = @config.find do |p|
      n, _ = parse_config_entry(p)
      n == name
    end
    config_entry || name
  end

  def parse_config_entry(p)
    if p.is_a?(Hash)
      name = p.keys.first
      config = p[name]
    else
      name = p
      config = nil
    end
    return name.to_sym, config
  end

  def do_load_plugins(to_load)
    return false unless to_load

    loading = []
    to_load.each do |p|
      name, config = parse_config_entry(p)
      unless plugins[name] # filter out already loaded plugins
        loading << [name, config]
      end
    end

    error = notify_listeners(:before_load, loading)
    if error
      puts "A PluginManager listener refuses accepting plugins: #{error}"
      return false
    end

    overall = nil
    begin
      loading.each do |name, config|
        overall = false if !do_load_plugin(name, config, loading)
      end

      loading.each do |name, _|
        if (plugin = @plugins[name])
          begin
            print "Initializing plugin #{name}..."
            plugin.afterLoad
            @router.register plugin
            puts "done."
          rescue ScriptError, StandardError => e
            puts "Cannot initialize plugin '#{name}': #{e}"
            overall = false
          end
        end
      end

      overall = true if overall == nil
    ensure
      notify_listeners(:after_load, loading)
    end

    overall
  end

  def do_load_plugin(name, config, loading)
    return true if plugins[name.to_sym] # success, if already loaded
    return false if name !~ /\A[a-zA-Z0-9]+\Z/m
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
          lacking << d unless (@plugins[d]) || (loading && loading.include?(d))
        end
        unless lacking.empty?
          raise "lacking dependencies: #{lacking}"
        end
      end

      print "Loading #{name}..."
      p = @plugins[name.to_sym] = pluginClass.new(self)
      p.config = (config || {}).freeze
      puts "done."
    rescue ScriptError, StandardError => e
      unload_plugin_class(name)
      puts "Cannot load plugin '#{name}': #{e}"
      return false
    end
    true
  end

  def unload_plugin_class(name)
    Object.send(:remove_const, name.to_sym)
  end

  def notify_listeners(method, list)
    @listeners.each do |listener|
      result = case method
                 when :before_load
                   listener.before_plugin_load(self, list)
                 when :after_load
                   listener.after_plugin_load(self, list)
                   nil # ignore returned value
                 when :before_unload
                   listener.before_plugin_unload(self, list)
                 when :after_unload
                   listener.after_plugin_unload(self, list)
                   nil # ignore returned value
                 else
                   raise ArgumentError, "Bug! Not one of predefined methods: #{method}"
               end
      return result if result # stop on first disagreeing handler
    end

    nil
  end
end
