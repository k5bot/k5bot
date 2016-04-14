# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# IRCPluginManager manages all plugins

class IRCPluginManager
  attr_reader :plugins

  def initialize()
    @plugins = {}
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

  def load_plugin(name)
    name, config = find_config_entry(name)

    do_load_plugins({ name => config })
  end

  def unload_plugin(name)
    name, config = find_config_entry(name)
    unloading = { name => config }

    error = notify_listeners(:before_unload, unloading)
    if error
      log(:error, "A PluginManager listener refuses unloading of plugins: #{error}")
      return false
    end

    unloaded = {}
    begin
      p = @plugins[name.to_sym]
      return false unless p

      dependants = []
      @plugins.keys.each do |suspectName|
        pluginClass = Kernel.const_get(suspectName.to_sym)
        dependants << suspectName if pluginClass::Dependencies and pluginClass::Dependencies.include? name.to_sym
      end

      unless dependants.empty?
        log(:error, "Cannot unload plugin '#{name}', the following plugins depend on it: #{dependants.join(', ')}")
        return false
      end

      log(:log, "Unloading #{name}...")
      error = do_before_unloading(p)
      if error
        log(:error, "'#{name}' refuses to unload: #{error}")
        return false
      end
      log(:log, "Unloaded #{name}.")

      unloaded[name] = config # Mark as unloaded

      @plugins.delete name.to_sym

      unload_plugin_class(name)
    rescue Exception => e
      log(:error, "Cannot unload plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}")
      return false
    ensure
      notify_listeners(:after_unload, unloaded)
    end

    true
  end

  def hot_reload_plugin(name)
    name = name.to_s
    return if name !~ /\A[a-zA-Z0-9]+\Z/m
    return unless @plugins[name.to_sym]
    requested = plugin_file_name(name)
    filename = Dir.glob(requested, File::FNM_CASEFOLD).first
    unless requested.eql?(filename)
      log(:error, "Cannot find plugin '#{name}'.")
      return false
    end
    load(filename)
  end

  protected

  # Must be overridden, in order to provide nonempty configuration
  def find_config_entry(name)
    [name, nil]
  end

  # May be overridden, in order to customize plugin post-load initialization
  def do_after_loading(plugin)
    plugin.afterLoad
  end

  # May be overridden, in order to customize plugin pre-unload deconstruction
  # @return nil, if unloading is successful, an error message otherwise
  def do_before_unloading(plugin)
    plugin.beforeUnload
  end

  def do_load_plugins(to_load)
    return false unless to_load

    loading = {}
    to_load.each do |name, config|
      unless plugins[name] # filter out already loaded plugins
        loading[name] = config
      end
    end

    error = notify_listeners(:before_load, loading)
    if error
      log(:error, "A PluginManager listener refuses accepting plugins: #{error}")
      return false
    end

    loaded = {}
    overall = nil
    begin
      loading.each do |name, config|
        overall = false if !do_load_plugin(name, config, loading)
      end

      loading.each do |name, config|
        if (plugin = @plugins[name])
          begin
            log(:log, "Initializing plugin #{name}...")
            do_after_loading(plugin)
            log(:log, "Initialized plugin #{name}.")

            loaded[name] = config # Mark as loaded
          rescue Exception => e
            log(:error, "Cannot initialize plugin '#{name}': #{e}\n\t#{e.backtrace.join("\n\t")}")
            overall = false

            # Remove the plugin, to avoid accidentally using it,
            # or worse, attempting to un-initialize it.
            @plugins.delete name.to_sym
            unload_plugin_class(name, true)
          end
        end
      end

      overall = true if overall == nil
    ensure
      notify_listeners(:after_load, loaded)
    end

    overall
  end

  def do_load_plugin(name, config, loading)
    return true if plugins[name.to_sym] # success, if already loaded
    return false if name !~ /\A[a-zA-Z0-9]+\Z/m
    begin
      requested = plugin_file_name(name)
      filename = Dir.glob(requested, File::FNM_CASEFOLD).first
      unless requested.eql? filename
        log(:error, "Cannot find plugin '#{name.to_s}'.")
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

      log(:log, "Loading #{name}...")
      @plugins[name.to_sym] = pluginClass.new(self, (config || {}).freeze)
      log(:log, "Loaded #{name}.")
    rescue Exception => e
      log(:error, "Cannot load plugin '#{name}': #{e}")
      unload_plugin_class(name, true)
      return false
    end
    true
  end

  def plugin_file_name(name)
    "#{File.dirname(__FILE__)}/plugins/#{name}/#{name}.rb"
  end

  def unload_plugin_class(name, fail_silently = false)
    begin
      Object.send(:remove_const, name.to_sym)
    rescue Exception => e
      if fail_silently
        log(:error, e)
      else
        raise e
      end
    end
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

  LOG_MODE_PREFIX = {:log => '=', :in => '>', :out => '<', :error => '!'}
  def log(mode, text)
    puts "#{LOG_MODE_PREFIX[mode]}#{self.class.name}: #{Time.now}: #{text}"
  end
end
