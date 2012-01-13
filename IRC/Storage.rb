# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Storage provides disk storage functionality

require 'yaml'
require 'fileutils'

class Storage
  def initialize(storagedirectory)
    @storagedirectory = storagedirectory || File.expand_path('~/.ircbot').chomp('/')
    FileUtils.mkdir_p(@storagedirectory)
  end

  # Writes data to store
  def write(store, data)
    return unless store && data
    FileUtils.mkdir_p(@storagedirectory)
    file = "#{@storagedirectory}/#{store}"
    File.open(file, 'w') do |io|
      YAML.dump(data, io)
    end
  end

  # Reads data from store
  def read(store)
    return unless store
    file = "#{@storagedirectory}/#{store}"
    return unless File.exist?(file)
    YAML.load_file(file)
  end
end