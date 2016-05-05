# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language UnicodeBlocks module

class Language
  module UnicodeBlocks
    attr_reader :unicode_desc

    def afterLoad
      super
      @unicode_blocks, @unicode_desc = load_unicode_blocks("#{plugin_root}/unicode_blocks.txt")
    end

    # Maps unicode codepoint to the index of respective unicode block
    def codepoint_to_block_id(codepoint)
      binary_search(@unicode_blocks, codepoint)
    end

    # @param [Integer] block_id - unicode block id
    # @return [Integer] first codepoint in the specified unicode block
    def block_id_to_codepoint(block_id)
      @unicode_blocks[block_id]
    end

    def block_id_to_description(block_id)
      @unicode_desc[block_id]
    end

    def classify_characters(text)
      text.unpack('U*').map do |codepoint|
        codepoint_to_block_id(codepoint)
      end
    end

    private

    def load_unicode_blocks(file_name)
      unknown_desc = :'Unknown Block'

      block_prev = -1
      blocks_indices = [] # First codepoints of unicode blocks
      blocks_descriptions = [] # Names of unicode blocks

      File.open(file_name, 'r') do |io|
        io.each_line do |line|
          line.chomp!.strip!
          next if line.nil? || line.empty? || line.start_with?('#')
          # 0000..007F; Basic Latin

          md = line.match(/^(\h+)..(\h+); (.*)$/)

          # next if md.nil?

          start = md[1].hex
          finish = md[2].hex
          desc = md[3].to_sym

          if block_prev + 1 < start
            # There is a gap between previous and current ranges
            # Fill this gap with dummy 'Unknown Block'
            blocks_indices << (block_prev + 1)
            blocks_descriptions << unknown_desc
          end
          block_prev = finish

          blocks_indices << start
          blocks_descriptions << desc
        end
      end

      # Everything past the last known block is unknown
      blocks_indices << (block_prev + 1)
      blocks_descriptions << unknown_desc

      [blocks_indices, blocks_descriptions]
    end

    def binary_search(arr, key)
      # index of the first X from the start, such that X<=key
      ((0...arr.size).bsearch {|i| arr[i] > key } || arr.size) - 1
    end
  end
end