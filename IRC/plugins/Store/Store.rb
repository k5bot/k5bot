# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Storage plugin

require 'yaml'
require 'fileutils'
require_relative '../../IRCPlugin'

class Store < IRCPlugin
  Description = "Provides storage functionality to other plugins."

  def afterLoad
    @directory = File.expand_path(@config[:directory] || '~/.ircbot').chomp('/')
  end

  def beforeUnload
    @directory = nil
  end

  # Writes data to store
  def write(store, data)
    return unless store && data
    FileUtils.mkdir_p(@directory)
    file = "#{@directory}/#{store}"
    File.open(file, 'w') do |io|
      YAML.dump(data, io)
    end
  end

  # Reads data from store
  def read(store)
    return unless store
    file = "#{@directory}/#{store}"
    return unless File.exist?(file)
    YAML.load_file(file)
  end
end
