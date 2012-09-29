# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# StorageYAML plugin. Provides disk storage functionality in YAML format.

require_relative '../../IRCPlugin'

require 'yaml'
require 'fileutils'

class StorageYAML < IRCPlugin

  Description = "Provides persistent storage in YAML format for other plugins."

  def afterLoad()
    dir = @config[:data_directory] || '~/.ircbot'
    @data_directory = File.expand_path(dir).chomp('/')
    FileUtils.mkdir_p(@data_directory)
  end

  def beforeUnload
    @data_directory = nil
  end

  # Writes data to store
  def write(store, data)
    return unless store && data
    FileUtils.mkdir_p(@data_directory)
    file = "#{@data_directory}/#{store}"
    File.open(file, 'w') do |io|
      YAML.dump(data, io)
    end
  end

  # Reads data from store
  def read(store)
    return unless store
    file = "#{@data_directory}/#{store}"
    return unless File.exist?(file)
    YAML.load_file(file)
  end
end
