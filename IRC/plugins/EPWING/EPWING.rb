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
@ for keyword search. No postfix is 'contains' search. ~ is the same, but
doesn't substitute gaiji. The exact meaning of search modes seems to vary \
with dictionary, so try and find what suits you best.",
      :gaiji => "Because EPWING dictionaries internally use JIS encodings, \
they can't represent lots of characters. As a workaround \
they use actual pictures instead, which they call 'GAIJI'. \
Whenever you see text like <?A2C4W?>, that's them. \
You can look up ASCII rendering of them using .gaiji? command. \
Using .gaiji command to supply unicode equivalents for gaiji \
is strongly encouraged.",
  }
  Dependencies = [ :Menu, :StorageYAML, :Router ]

  def commands
    book_cmds = @books.each_pair.map do |command, book_record|
      [
          command,
          {
              nil => "looks up given word in #{book_record.title}. See '.help #{name}' for more info."
          }.merge(book_record.help_extension)
      ]
    end
    Hash[book_cmds].merge(
        :epwing => "looks up given word in all opened EPWING dictionaries. \
See '.help #{name}' for more info.",
        :gaiji => "supplies given replacement symbol(s) for specified gaiji in \
specified dictionary. See '.help #{name} gaiji' for more info. \
Example: .gaiji daijirin WD500 (1) <-- to add (1) as replacement for <?WD500?> \
in Daijirin. Example: .gaiji daijirin WD500 <-- to remove existing mapping \
for WD500 in Daijirin.",
        :'gaiji?' => "renders in ASCII symbol for specified gaiji in \
specified dictionary. Use .gaiji?? and .gaiji??? for different formats. \
See '.help #{name} gaiji' for more info. Example: .gaiji? daijirin WD500",
    )
  end

  def afterLoad
    load_helper_class(:EPWINGMenuEntry)

    @router = @plugin_manager.plugins[:Router]
    @m = @plugin_manager.plugins[:Menu]
    @storage = @plugin_manager.plugins[:StorageYAML]

    books = @config.map do |book_id, book_config|
      command = (book_config[:command] || book_id.to_s.downcase).to_sym
      path = book_config[:path] or raise "EPWING configuration error! Book path for #{book_id} must be defined."
      subbook = book_config[:subbook] || 0
      help_extension = book_config[:help] || {}
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
                          :command => command,
                          :help_extension => help_extension,
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
    @router = nil

    unload_helper_class(:EPWINGMenuEntry)

    nil
  end

  SPACE_REGEXP = /[ 　]+/
  USER_GAIJI_REGEXP = /^[WwNn]\h{4}$/

  def on_privmsg(msg)
    word = msg.tail
    return unless word

    botcommand = msg.botcommand
    return unless botcommand

    m = botcommand.to_s.match(/(.+)([!$@~])$/)
    if m
      lookup_type = case m[2]
                      when '!'
                        :exact
                      when '$'
                        :ends_with
                      when '@'
                        :keyword
                      when '~'
                        :preserve_gaiji
                      else
                        raise "Bug! Parse failure of #{botcommand}"
                     end
      botcommand = m[1].to_sym
    else
      lookup_type = :contains
    end

    case botcommand
      when :gaiji
        change_gaiji(msg, word)
      when :'gaiji?'
        display_gaiji(msg, word, [' ','▄','▀','█'])
      when :'gaiji??'
        display_gaiji(msg, word, %w(░ ▄ ▀ █))
      when :'gaiji???'
        display_gaiji(msg, word, %w(░ ▓)) # 'Ｏ', '　'
      when :epwing
        return unless check_and_complain(@router, msg, :can_use_mass_epwing_lookup)

        lookups = @books.map do |_, book_record|
          l_up = lookup(book_record, word, lookup_type)
          [book_record, l_up]
        end

        menus = lookups.map do |book_record, lookup|
          if lookup.size > 0
            description = "#{book_record.command} (#{lookup.size} #{pluralize('hit', lookup.size)})"
            generate_menu(
                lookup,
                description,
                msg.private?,
                book_record,
                lookup_type == :preserve_gaiji)
          end
        end.reject {|x| !x}

        reply_with_menu(msg, MenuNodeSimple.new("#{word} in EPWING dictionaries", menus))
      else
        book_record = @books[botcommand]
        if book_record
          book_lookup = lookup(book_record, word, lookup_type)
          reply = generate_menu(
              book_lookup,
              "#{word} in #{book_record.title}",
              msg.private?,
              book_record,
              lookup_type == :preserve_gaiji)
          reply_with_menu(msg, reply)
        end
    end
  end

  private

  def generate_menu(lookup, name, is_private, book_record, preserve_gaiji)
    menu = lookup.map do |heading, text|
      EPWINGMenuEntry.new(
          heading,
          text.each_slice(is_private ? 10 : 3).to_a,
          book_record,
          preserve_gaiji
      )
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
               when :contains, :preserve_gaiji
                 book.search(convert_to_eb(word))
               when :exact
                 book.exactsearch(convert_to_eb(word))
               when :ends_with
                 book.endsearch(convert_to_eb(word))
               when :keyword
                 book.keywordsearch(convert_to_eb(word).split(SPACE_REGEXP))
               else
                 raise "Bug! Unknown lookup type #{lookup_type.inspect}"
             end
    lookup.uniq!
    lookup.map do |heading, text|
      [
          heading,
          text.split("\n")
      ]
    end
  rescue Exception => e
    puts "Error looking up in #{book.title}: #{e.inspect} #{e.backtrace}"
    []
  end

  def convert_to_eb(word)
    word.encode('EUC-JP')
  end

  def convert_from_eb(word)
    word.encode('UTF-8')
  end

  def pluralize(str, num)
    num != 1 ? str + 's' : str
  end

  def check_and_complain(checker, msg, permission)
    if checker.check_permission(permission, msg_to_principal(msg))
      true
    else
      msg.reply("Sorry, you don't have '#{permission}' permission.")
      false
    end
  end

  def msg_to_principal(msg)
    msg.prefix
  end

  def change_gaiji(msg, word)
    return unless check_and_complain(@router, msg, :can_add_gaiji)
    dictionary, gaiji, replacement = word.split(SPACE_REGEXP, 3)
    book_record = @books[dictionary.downcase.to_sym]
    unless book_record
      msg.reply("Unknown dictionary name '#{dictionary}'. Must be one of: #{@books.keys.join(', ')}")
      return
    end
    unless gaiji && gaiji.match(USER_GAIJI_REGEXP)
      msg.reply('Gaiji must be in format Wxxxx or Nxxxx, where xxxx are hexadecimal digits.')
      return
    end
    gaiji = gaiji.upcase.to_sym
    previous_value = book_record.gaiji_data[gaiji]
    if replacement
      book_record.gaiji_data[gaiji] = replacement
      msg.reply("Replaced #{gaiji} in dictionary '#{dictionary}' with #{replacement}#{" (was #{previous_value})" if previous_value}.")
    elsif previous_value
      book_record.gaiji_data.delete(gaiji)
      msg.reply("Removed mapping for #{gaiji} in dictionary '#{dictionary}'#{" (was #{previous_value})" if previous_value}.")
    else
      msg.reply("Can't remove non-existing mapping for #{gaiji} in dictionary '#{dictionary}'.")
    end

    store_gaiji(book_record)
  end

  def store_gaiji(book_record)
    @storage.write(book_record.gaiji_file, book_record.gaiji_data)
  end

  def display_gaiji(msg, word, charmap)
    return unless check_and_complain(@router, msg, :can_add_gaiji)
    dictionary, gaiji = word.split(SPACE_REGEXP, 2)
    book_record = @books[dictionary.downcase.to_sym]
    unless book_record
      msg.reply("Unknown dictionary name '#{dictionary}'. Must be one of: #{@books.keys.join(', ')}")
      return
    end

    gaiji = gaiji.upcase
    m = gaiji && gaiji.match(/([WN])(\h{4})/)
    unless m
      msg.reply('Gaiji must be in format Wxxxx or Nxxxx, where xxxx are hexadecimal digits.')
      return
    end
    gaiji = gaiji.to_sym

    previous_value = book_record.gaiji_data[gaiji]

    code = m[2].to_i(16)

    font_codes = book_record.book.fontcode_list.dup
    font_codes.sort_by!{|x| -x}

    book_record.book.fontcode=font_codes.first

    begin
      font = if m[1] == 'W'
               book_record.book.get_widefont(code)
             else
               book_record.book.get_narrowfont(code)
             end
    rescue Exception => _
      msg.reply("Failed to obtain bitmap for #{gaiji} in dictionary '#{dictionary}'.")
      return
    end

    x = font.to_xpm

    lines = []
    skipped_first = 0
    skipped_last = 0

    x = x.each_line.to_a
    x.slice!(0, 5) # truncate out the XPM header

    x.each do |l|
      m = l.match(/^"(.+)"/)
      next unless m
      r = m[1]
      r.gsub!(/\S/, '1')
      r.gsub!(/\s/, '0')
      lines << r
    end

    case charmap.size
    when 4
      lines = lines.each_slice(2).map do |top_line, bottom_line|
        top_line.each_char.zip(bottom_line.each_char).map do |top_char, bottom_char|
          x = top_char == '0' ? 0 : 2
          y = bottom_char == '0' ? 0 : 1
          charmap[x+y]
        end.join
      end

      while lines.first.delete(charmap[0]).empty?
        lines.shift
        skipped_first += 1
      end

      while lines.last.delete(charmap[0]).empty?
        lines.pop
        skipped_last += 1
      end
    when 2
      lines.each do |l|
        l.gsub!(/0/, charmap[0])
        l.gsub!(/1/, charmap[1])
      end
    else
      raise "Bug! Charmap size is #{charmap.size}"
    end

    if skipped_first > 0
      msg.reply("(#{skipped_first} empty #{pluralize('line', skipped_first)} skipped)")
    end

    lines.each do |l|
      msg.reply(l)
    end

    if skipped_last > 0
      msg.reply("(#{skipped_last} empty #{pluralize('line', skipped_last)} skipped)")
    end

    msg.reply("Currently set as #{previous_value}") if previous_value
  end
end
