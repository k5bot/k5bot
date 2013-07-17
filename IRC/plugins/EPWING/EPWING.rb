# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# EPWING plugin. Provides lookup functionality for dictionaries in EPWING format.

require 'rubygems'
require 'bundler/setup'
require 'eb'
require 'ostruct'

require_relative '../../IRCPlugin'

class EPWING < IRCPlugin
  Description = 'Plugin for working with dictionaries in EPWING format.'
  Dependencies = [ :Menu, :StorageYAML ]

  def commands
    book_cmds = @books.each_pair.map do |command, book_record|
      [command, "looks up given word in #{book_record.title}"]
    end
    Hash[book_cmds].merge(:epwing => 'looks up given word in all opened EPWING dictionaries')
  end

  def afterLoad
    @m = @plugin_manager.plugins[:Menu]

    books = @config.map do |book_id, book_config|
      command = (book_config[:command] || book_id.to_s.downcase).to_sym
      path = book_config[:path] or raise "EPWING configuration error! Book path for #{book_id} must be defined."
      subbook = book_config[:subbook] || 0

      book = EB::Book.new
      begin
        book.bind(path)
        book.subbook = subbook
      rescue Exception => e
        raise "Failed opening #{book_id}: #{e.inspect} #{e.backtrace}"
      end

      title = config[:title] || convert_from_eb(book.title(subbook))

      [command, OpenStruct.new({:book => book, :title => title})]
    end

    @books = Hash[books]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @books = nil

    @m = nil

    nil
  end

  def on_privmsg(msg)
    word = msg.tail
    return unless word

    case msg.botcommand
      when :epwing
        lookups = @books.map do |_, book_record|
          [book_record.title, lookup_containing(book_record.book, word)]
        end

        menus = lookups.map do |book_title, lookup|
          generate_menu(lookup, book_title)
        end

        reply_with_menu(msg, MenuNodeSimple.new("#{word} in EPWING dictionaries", menus))
      else
        book_record = @books[msg.botcommand]
        if book_record
          book_lookup = lookup_containing(book_record.book, word)
          reply = generate_menu(book_lookup, "#{word} in #{book_record.title}")
          reply_with_menu(msg, reply)
        end
    end
  end

  private

  def generate_menu(lookup, name)
    menu = lookup.map do |heading, text|
      MenuNodeTextEnumerable.new(heading, text)
    end

    MenuNodeSimple.new(name, menu)
  end

  def reply_with_menu(msg, result)
    @m.put_new_menu(
        self.name,
        result,
        msg
    )
  end

  # Looks up all words containing given text
  def lookup_containing(book, word)
    lookup = book.search(convert_to_eb(word))
    lookup.uniq!
    lookup.map do |heading, text|
      [convert_from_eb(heading), convert_from_eb(text).split("\n")]
    end
  end

  def convert_to_eb(word)
    word.encode('EUC-JP')
  end

  def convert_from_eb(word)
    word.encode('UTF-8')
  end

end
