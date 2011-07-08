# encoding: utf-8

require 'yaml'

class String
	Rom2kana = YAML.load_file('rom2kana.yaml')
	Rom = Rom2kana.keys.sort_by{|x| -x.length}

	def to_kana
		kana = self.dup
		Rom.each do |r|
			kana.gsub!(r, Rom2kana[r])
		end
		kana
	end
end
