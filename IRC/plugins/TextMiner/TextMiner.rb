# encoding: utf-8

require 'set'

require_relative '../../IRCPlugin'

class TextMiner < IRCPlugin
  Description = "TextMiner plugin provides access, search, \
and stats for underlying text corpus."

  Dependencies = [ :Language ]

  Commands = {
      :example => "Searches all files for lines containing a given text. \
Repeated invocation with the same text or without text at all is equivalent \
to .nextexample",
      :exampler => 'Same as .example, but accepts a regexp.',
      :nextexample =>
          "Returns the next one from the lines found by .example/regexample. \
Optionally accepts a number(can be negative) for relative jumping.",
      :context =>
          "Moves to and shows preceeding line in current file. \
Optionally accepts a number(can be negative) for relative jumping.",
      :contextf => 'Same as .context, but moves forward.',
      :wherefrom => 'Shows which file the last viewed line is from.',
      :vnhits => 'Shows how many times a given text occurs per each file.',
      :vnhitsr => 'Same as .vnhits, but accepts a regexp.',
      :wordcount => 'Shows usage counts in all files for given words.',
      :wordfight => 'Same as .wordcount, but also sorted by frequency.',
  }

  MAX_VNHITS_LINES = 2

  def afterLoad
    dir = @config[:data_directory]
    dir ||= '~/.ircbot/text'

    @data_directory = File.expand_path(dir).chomp('/')

    @files = Dir.entries(@data_directory).map do |path|
      File.join(@data_directory, path)
    end.find_all do |path|
      File.file?(path)
    end.map do |path|
      MinedText.new(File.basename(path, '.txt'), path)
    end

    @cache_tracking = {}
    @line_searches = {}
    @occurrence_searches = {}
    @occurrence_map_searches = {}
    @navigations = {}
  end

  def beforeUnload
    @navigations = nil
    @occurrence_map_searches = nil
    @occurrence_searches = nil
    @line_searches = nil
    @cache_tracking = nil

    @files = nil
    @data_directory = nil

    nil
  end

  def on_privmsg(msg)
    word = msg.tail
    nav = @navigations[msg.context]

    case msg.bot_command
      when :context, :contextf
        return unless nav && !nav.empty?
        increment = word || '1'
        increment = increment.to_i
        increment = -increment if :context.eql?(msg.bot_command)

        nav.browse_offset += increment
        msg.reply(nav.current_line)

      when :nextexample
        return unless nav && !nav.empty?
        increment = word || '1'
        increment = increment.to_i

        nav.move_to_example(nav.example_index + increment)
        msg.reply(nav.current_line)

      when :wherefrom
        return unless nav && !nav.empty?
        hit_file, line_no = nav.current_line_index
        msg.reply("Last example from #{hit_file.name}, #{line_no+1}/#{hit_file.lines_num}")

      when :vnhits, :vnhitsr
        queries =
                if word
                  if :vnhits.eql?(msg.bot_command)
                    # Find occurrences of all words in given space-separated list
                    word.split.uniq.map{|w| ContainsQuery.new(w)}
                  else
                    [RegexpAllQuery.new(Language.parse_complex_regexp_raw(word).flatten, word)]
                  end
                else
                  # If given no arguments, assume the user wanted info for
                  # what he queried last with .example/regexample.
                  nav ? [nav.query] : []
                end

        return if queries.empty?

        ensure_searches([msg.context, :vnhits], [:occurrence], *queries)

        counts = queries.each_with_object({}) do |query, h|
          result = @occurrence_searches[query]

          result.hit_files.zip(result.occurrence_counts).each do |file, cnt|
            h[file] ||= 0
            h[file] += cnt
          end
        end

        counts = counts.sort_by{|_, s| -s}.map{|f, s| [f.name, s]}
        occurrences_total = counts.map{|_, s| s}.inject(0, :+)

        unless occurrences_total > 0
          msg.reply("Not found \"#{queries.join(' ')}\" in TextMiner")
          return
        end

        last_line = "#{occurrences_total} total, \
appears in #{counts.size}/#{@files.size} scripts)"

        reply_untruncated(msg, counts, MAX_VNHITS_LINES) do |chunk, remainder|
          line = chunk.map{|n, s| "#{n}: #{s}"}.join(', ')
          if remainder
            line += ' ('
            unless remainder.empty?
              line += "#{remainder.map { |_, s| s }.inject(0, :+)} in the rest, "
            end
            line += last_line
          end
          line
        end

      when :example, :exampler, :regexample
        query = if word
                  if :example.eql?(msg.bot_command)
                    ContainsQuery.new(word)
                  else
                    RegexpAllQuery.new(Language.parse_complex_regexp_raw(word).flatten, word)
                  end
                elsif nav && nav.query
                  # If given no arguments, assume the user wanted
                  # the next line of what he queried last, assuming
                  # the query type (plaintext/regexp) matches.
                  if :example.eql?(msg.bot_command)
                    nav.query.is_a?(ContainsQuery)
                  else
                    nav.query.is_a?(RegexpAllQuery)
                  end && nav.query
                end

        return unless query

        first_browsing = false
        unless nav && (nav.query == query)
          first_browsing = true
          ensure_searches([msg.context, :example], [:line], query)
          nav = LineSearchResultNavigator.new(@line_searches[query])
          nav.randomize_current_line!
          @navigations[msg.context] = nav
        end

        if nav.empty?
          msg.reply("Not found \"#{nav.query}\" in TextMiner") if word
          return
        end

        # Ensure movement if user searches the same word or with no arguments.
        nav.move_to_example(nav.example_index + 1)

        reply = nav.current_line
        # Print found lines count if this is the first search for given query
        reply += " (Hits: #{nav.lines_total})" if first_browsing
        msg.reply(reply)

      when :wordfight, :wordcount
        return unless word
        queries = word.split.uniq.map {|w| ContainsQuery.new(w)}
        ensure_searches([msg.context, :wordcount], [:occurrence], *queries)
        results = queries.map {|q| @occurrence_searches[q]}
        results = results.map {|r| [r.occurrences_total, r.query]}

        if :wordfight.eql?(msg.bot_command)
          # Sort and chunk into equivalence classes by occurrence count
          results = results.sort_by {|s, _| -s}.chunk {|s, _| s}.map(&:last)
          reply = results.map do |equiv|
            equiv.map do |s, w|
              "#{w} (#{s})"
            end.join(' = ')
          end.join(' > ')
        else
          reply = results.map do |s, w|
            "#{w} (#{s})"
          end.join(', ')
        end
        msg.reply(reply)
    end
  end

  private

  def ensure_searches(cache_key, query_type, *queries)
    # Try to optimize a bit, in case someone throws identical queries at us.
    query_type = query_type.uniq
    queries = queries.uniq

    # Register the queries as not eligible for purging.
    @cache_tracking[cache_key] = queries

    # Extend queries for caching reasons. E.g.
    # if we need to count occurrences, opt in for filling line indices too.
    # Since we're not using SQL, it's not going to be much slower
    # than finding occurrences already is, but will help for related queries.
    query_type |= [:occurrence] if query_type.include?(:occurrence_map)
    query_type |= [:line] if query_type.include?(:occurrence)

    query_groups = queries.group_by do |query|
      qt = query_type.dup
      qt.delete(:line) if @line_searches.include?(query)
      qt.delete(:occurrence) if @occurrence_searches.include?(query)
      qt.delete(:occurrence_map) if @occurrence_map_searches.include?(query)
      qt
    end

    query_groups.each do |qt, qs|
      fill_searches(qt, *qs)
    end

    purge_unused_cache!
  end

  def fill_searches(query_type, *queries)
    return if query_type.empty?

    line_results = if query_type.include?(:line)
                     queries.map do |query|
                       LineSearchResult.new(query)
                     end
                   end
    occurrence_results = if query_type.include?(:occurrence)
                           queries.map do |query|
                             OccurrencesSearchResult.new(query)
                           end
                         end
    occurrence_map_results = if query_type.include?(:occurrence_map)
                               queries.map do |query|
                                 OccurrenceMapsSearchResult.new(query)
                               end
                             end

    @files.each do |hit_file|
      found_lines = found_occurrences = found_occurrence_maps = nil

      if occurrence_map_results
        if line_results
          found_lines, found_occurrence_maps = hit_file.find_lines_with_occ_maps(queries)
        else
          found_occurrence_maps = hit_file.find_occurrences(queries)
        end
      end

      if occurrence_results
        if found_occurrence_maps
          found_occurrences = found_occurrence_maps.map do |occ_map|
            occ_map.values.inject(0, :+)
          end
        elsif line_results && !found_lines
          found_lines, found_occurrences = hit_file.find_lines_with_occurrences(queries)
        else
          found_occurrences = hit_file.find_occurrences(queries)
        end
      end

      if line_results && !found_lines
        found_lines = hit_file.find_lines(queries)
      end

      line_results.zip(found_lines) do |result, line_indices|
        result.add_indices(hit_file, line_indices)
      end if line_results
      occurrence_results.zip(found_occurrences) do |result, full_count|
        result.add_counts(hit_file, full_count)
      end if occurrence_results
      occurrence_map_results.zip(found_occurrence_maps) do |result, occ_map|
        result.add_map(hit_file, occ_map)
      end if occurrence_map_results
    end

    line_results.each do |result|
      @line_searches[result.query] ||= result
    end if line_results
    occurrence_results.each do |result|
      @occurrence_searches[result.query] ||= result
    end if occurrence_results
    occurrence_map_results.each do |result|
      @occurrence_map_searches[result.query] ||= result
    end if occurrence_map_results
  end

  def purge_unused_cache!
    used_queries = Set.new(@cache_tracking.values.flatten(1))
    @line_searches.keep_if {|k,_| used_queries.include?(k) }
    @occurrence_searches.keep_if {|k,_| used_queries.include?(k) }
    @occurrence_map_searches.keep_if {|k,_| used_queries.include?(k) }
  end

  #TODO: implement navigation expiration
  #def purge_expired_nav!
  #  @navigations.reject! { |_, v| v.is_expired? }
  #end

  def reply_untruncated(msg, output_array, max_lines = nil)
    until output_array.empty? || (max_lines && max_lines <= 0)
      max_lines -= 1
      chunk_size = output_array.size
      begin
        # Remainder contains:
        # 1) nil, if this is not the last iteration before stopping
        # 2) [], if this is the last iteration but we didn't exceed max_lines
        # and hence printed everything we were given
        # 3) array elements that were chosen to be not printed, b/c now is the last
        # iteration and we can't print any more lines due to max_lines restriction.
        remainder = if (max_lines && max_lines <= 0) || (chunk_size == output_array.size)
          output_array.slice(chunk_size..-1)
        end

        output_string = yield(output_array[0..chunk_size-1], remainder)

        msg.reply(output_string, :dont_truncate => (chunk_size > 1))
      rescue
        chunk_size -= 1
        retry if chunk_size > 0
      end
      output_array.slice!(0, chunk_size)
    end
  end

  class MinedText
    attr_reader :name

    def initialize(name, path)
      @name = name
      @lines = File.open(path) do |io|
        io.each_line.map {|l| l.chomp }
      end
    end

    def get_line(idx)
      @lines[idx]
    end

    def lines_num
      @lines.size
    end

    # The next three procs have different performance,
    # especially if reimplemented as SQL queries,
    # so I decided to split them, even though they don't differ much
    # and could be unified to one proc.

    def find_lines(queries)
      lookup = Array.new(queries.size) { [] }
      @lines.each_with_index do |l, line_idx|
        queries.each_with_index do |query, arr_idx|
          lookup[arr_idx] << line_idx if (query === l)
        end
      end
      lookup
    end

    def find_occurrences(queries)
      lookup_counts = Array.new(queries.size) { 0 }
      @lines.each do |l|
        queries.each_with_index do |query, arr_idx|
          match_count = query.count_occurrences(l)
          lookup_counts[arr_idx] += match_count
        end
      end
      lookup_counts
    end

    def find_occurrence_maps(queries)
      lookup_maps = Array.new(queries.size) { Hash.new(0) }
      @lines.each do |l|
        queries.each_with_index do |query, arr_idx|
          query.count_occurrences_map(l, lookup_maps[arr_idx])
        end
      end
      lookup_maps
    end

    def find_lines_with_occurrences(queries)
      lookup = Array.new(queries.size) { [] }
      lookup_counts = Array.new(queries.size) { 0 }
      @lines.each_with_index do |l, line_idx|
        queries.each_with_index do |query, arr_idx|
          match_count = query.count_occurrences(l)
          if match_count > 0
            lookup[arr_idx] << line_idx
            lookup_counts[arr_idx] += match_count
          end
        end
      end
      [lookup, lookup_counts]
    end

    def find_lines_with_occ_maps(queries)
      lookup = Array.new(queries.size) { [] }
      lookup_maps = Array.new(queries.size) { Hash.new(0) }
      @lines.each_with_index do |l, line_idx|
        queries.each_with_index do |query, arr_idx|
          match_count = query.count_occurrences_map(l, lookup_maps[arr_idx])
          lookup[arr_idx] << line_idx if match_count > 0
        end
      end
      [lookup, lookup_maps]
    end
  end

  class LineSearchResult
    attr_reader :query,
                :hit_files,
                :line_indices,
                :lines_total

    def initialize(query)
      @query = query
      @hit_files = []
      @line_indices = []
      @lines_total = 0
    end

    def empty?
      0 >= @lines_total
    end

    def add_indices(hit_file, line_indices)
      return if line_indices.empty?
      @hit_files << hit_file
      @line_indices << line_indices
      @lines_total += line_indices.size
    end
  end

  class OccurrencesSearchResult
    attr_reader :query,
                :hit_files,
                :occurrence_counts,
                :occurrences_total

    def initialize(query)
      @query = query
      @hit_files = []
      @occurrence_counts = []
      @occurrences_total = 0
    end

    def empty?
      0 >= @occurrences_total
    end

    def add_counts(hit_file, full_count)
      return unless full_count > 0
      @hit_files << hit_file
      @occurrence_counts << full_count
      @occurrences_total += full_count
    end
  end

  class OccurrenceMapsSearchResult
    attr_reader :query,
                :hit_files,
                :occurrence_maps,
                :occurrence_total_map

    def initialize(query)
      @query = query
      @hit_files = []
      @occurrence_maps = []
      @occurrence_total_map = {}
    end

    def empty?
      @occurrence_maps.empty?
    end

    def add_map(hit_file, occurence_map)
      return if occurence_map.empty?
      @hit_files << hit_file
      @occurrence_maps << occurence_map
      @occurrence_total_map.merge!(occurence_map) do |key, old_val, new_val|
        old_val + new_val
      end
    end
  end

  class LineSearchResultNavigator
    attr_reader :search_result,
                :example_index,
                :browse_offset

    def initialize(search_result)
      @search_result = search_result
      @example_index = 0
      @browse_offset = 0
    end

    def empty?
      @search_result.empty?
    end

    def query
      @search_result.query
    end

    def lines_total
      @search_result.lines_total
    end

    def browse_offset=(v)
      @browse_offset = v
    end

    def move_to_example(v)
      @browse_offset = 0
      @example_index = if @search_result.lines_total > 0
                         v % @search_result.lines_total
                       else
                         0
                       end
    end

    def randomize_current_line!
      @browse_offset = 0
      @example_index = if @search_result.lines_total > 0
                         Random.rand(self.lines_total)
                       else
                         0
                       end
    end

    def current_line_index
      return if empty?
      file_no, line_no = nested_index(@search_result.line_indices, @example_index)
      hit_file = @search_result.hit_files[file_no]
      line_no = @search_result.line_indices[file_no][line_no]
      line_no += @browse_offset
      line_no %= hit_file.lines_num
      [hit_file, line_no]
    end

    def current_line
      return if empty?
      hit_file, line_no = current_line_index
      hit_file.get_line(line_no)
    end

    private

    def nested_index(coll, idx)
      coll.each_with_index do |e, i|
        s = e.size
        return [i, idx] if idx < s
        idx -= s
      end
      raise 'Bug!'
    end
  end

  class ContainsQuery
    attr_reader :word

    def initialize(word, str_rep = nil)
      @word = word
      # Cache regexp for faster occurrence search with String.scan()
      @regexp = Regexp.new(Regexp.quote(word))
      @str_rep = str_rep
    end

    def ===(s)
      s.include?(@word)
    end

    def count_occurrences(s)
      s.scan(@regexp).size
    end

    def count_occurrences_map(s, h)
      cnt = count_occurrences(s)
      h[@word] += cnt
      cnt
    end

    def to_s
      @str_rep || @word
    end

    # Equality methods for good in-hash behavior
    def eql?(o)
      o.class == self.class && o.word == @word
    end
    alias_method(:==, :eql?)
    def hash
      @word.hash
    end
  end

  class RegexpAllQuery
    attr_reader :main_regexp, :aux_regexps, :aux_regexps_equ

    def initialize(regexps, str_rep = nil)
      # For occurrences, we count the matches of the first regexp,
      # so split it out now. The rest of regexps merely define
      # additional requirements on a given line
      # for those matches to be counted.
      @main_regexp, *@aux_regexps = regexps
      # Order of regexps matters, performance- and nesting-wise,
      # so preserve it, and use an additional set for tail equality instead.
      @aux_regexps_equ = Set.new(@aux_regexps)
      @str_rep = str_rep
    end

    def ===(s)
      @main_regexp.match(s) && @aux_regexps.all?{|w| w.match(s)}
    end

    def count_occurrences(s)
      @aux_regexps.all?{|w| w.match(s)} ? s.scan(@main_regexp).size : 0
    end

    def count_occurrences_map(s, h)
      return 0 unless @aux_regexps.all? { |w| w.match(s) }
      scanned = s.scan(@main_regexp)
      if scanned.first.instance_of?(Array)
        scanned.each do |a|
          h[a.join('_')] += 1
        end
      else
        scanned.each do |w|
          h[w] += 1
        end
      end
      scanned.size
    end

    def to_s
      @str_rep || [@main_regexp, *@aux_regexps].join(' ')
    end

    # Equality methods for good in-hash behavior
    def eql?(o)
      o.class == self.class &&
          o.main_regexp == @main_regexp &&
          o.aux_regexps_equ == @aux_regexps_equ
    end
    alias_method(:==, :eql?)
    def hash
      @main_regexp.hash + @aux_regexps_equ.hash
    end
  end
end
