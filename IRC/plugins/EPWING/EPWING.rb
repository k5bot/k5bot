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
  Description = {
      nil => 'Plugin for working with dictionaries in EPWING format.',
      :search => "Searching is straightforward, but it's worth noting that \
since used EPWING library searches both English and Japanese words via \
the same call, no convenient input word mangling is done. In particular, \
text in ro-maji isn't converted to kana, you must do it yourself. You can \
also use .epwing command to search in all available dictionaries simultaneously.",
      :postfix => "Search commands can \
(where supported by underlying dictionary) be postfixed with \
one of the following: ! for exact search, $ for ends-with search, \
@ for keyword search. No postfix is 'contains' search. \
The exact meaning of those seems to vary with dictionary, so try and find \
what suits you best.",
      :gaiji => "Because EPWING dictionaries internally use JIS encodings, \
they can't represent lots of characters. As a workaround \
they use actual pictures instead, which they call 'GAIJI'. \
Whenever you see text like <?A2C4W?>, that's them. Meanwhile, \
you can ask me to upload corresponding pic somewhere, \
until I automate the uploading and add possibility for users to suggest \
Unicode equivalents.",
  }
  Dependencies = [ :Menu, :StorageYAML ]

  def commands
    book_cmds = @books.each_pair.map do |command, book_record|
      [command, "looks up given word in #{book_record.title}. See '.help #{name}' for more info."]
    end
    Hash[book_cmds].merge(
        :epwing => "looks up given word in all opened EPWING dictionaries. \
See '.help #{name}' for more info."
    )
  end

  def afterLoad
    @m = @plugin_manager.plugins[:Menu]
    @storage = @plugin_manager.plugins[:StorageYAML]

    books = @config.map do |book_id, book_config|
      command = (book_config[:command] || book_id.to_s.downcase).to_sym
      path = book_config[:path] or raise "EPWING configuration error! Book path for #{book_id} must be defined."
      subbook = book_config[:subbook] || 0
      gaiji_file = book_config[:gaiji] || "gaiji_#{book_id}"

      gaiji_data = @storage.read(gaiji_file) || {}

      book = EB::Book.new
      begin
        book.bind(path)
        book.subbook = subbook
      rescue Exception => e
        raise "Failed opening #{book_id}: #{e.inspect} #{e.backtrace}"
      end

      title = config[:title] || convert_from_eb(book.title(subbook))

      hookset = EB::Hookset.new

      book.hookset=hookset

      hookset.register(EB::HOOK_WIDE_FONT) do |_, argv|
        char_code = argv[0].to_s(16).upcase.to_sym
        convert_to_eb("<?W#{char_code}?>")
      end

      hookset.register(EB::HOOK_NARROW_FONT) do |_, argv|
        char_code = argv[0].to_s(16).upcase.to_sym
        convert_to_eb("<?N#{char_code}?>")
      end

      [command,
       OpenStruct.new({
                          :book => book,
                          :title => title,
                          :gaiji_file => gaiji_file,
                          :gaiji_data => gaiji_data,
                      })]
    end

    @books = Hash[books]
  end

  def beforeUnload
    @m.evict_plugin_menus!(self.name)

    @books = nil

    @m = nil
    @storage = nil

    nil
  end

  def on_privmsg(msg)
    word = msg.tail
    return unless word

    botcommand = msg.botcommand
    return unless botcommand

    m = botcommand.to_s.match(/(.+)([!$@])$/)
    if m
      lookup_type = case m[2]
                      when '!'
                        :exact
                      when '$'
                        :ends_with
                      when '@'
                        :keyword
                      else
                        raise "Bug! Parse failure of #{botcommand}"
                     end
      botcommand = m[1].to_sym
    else
      lookup_type = :contains
    end

    case botcommand
      when :epwing
        lookups = @books.map do |_, book_record|
          l_up = lookup(book_record, word, lookup_type)
          ["#{book_record.title} (#{l_up.size} hit(s))", l_up]
        end

        menus = lookups.map do |book_title, lookup|
          generate_menu(lookup, book_title) if lookup.size > 0
        end.reject {|x| !x}

        reply_with_menu(msg, MenuNodeSimple.new("#{word} in EPWING dictionaries", menus))
      else
        book_record = @books[botcommand]
        if book_record
          book_lookup = lookup(book_record, word, lookup_type)
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
  def lookup(book_record, word, lookup_type)
    book = book_record.book
    lookup = case lookup_type
               when :contains
                 book.search(convert_to_eb(word))
               when :exact
                 book.exactsearch(convert_to_eb(word))
               when :ends_with
                 book.endsearch(convert_to_eb(word))
               when :keyword
                 book.keywordsearch(convert_to_eb(word).split(/[ 　]+/))
               else
                 raise "Bug! Unknown lookup type #{lookup_type.inspect}"
             end
    lookup.uniq!
    lookup.map do |heading, text|
      [
          format_text(heading, book_record.gaiji_data),
          format_text(text, book_record.gaiji_data).split("\n")
      ]
    end
  rescue Exception => e
    puts "Error looking up in #{book.title}: #{e.inspect} #{e.backtrace}"
    []
  end

  def format_text(text, gaiji_data)
    replace_gaiji(convert_from_eb(text), gaiji_data)
  end

  def replace_gaiji(text, gaiji_data)
    text.gsub(/<\?([WN]\h{4})\?>/) do |_|
      gaiji_data[$1.to_sym] || "<?#{$1}?>"
    end
  end

  def convert_to_eb(word)
    word.encode('EUC-JP')
  end

  def convert_from_eb(word)
    word.encode('UTF-8')
  end

end
