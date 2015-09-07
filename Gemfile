ruby '2.1.2'

source "https://rubygems.org"

# for WolframAlpha plugin
git 'https://github.com/albel727/wolfram.git' do
  gem 'wolfram', :group => :WolframAlpha
end

# for Mecab plugin
git 'https://github.com/albel727/mecab-ruby-gem.git' do
  gem 'mecab-ruby', :group => :Mecab
end

# for KANJIDIC2, Translate, URL plugins
gem 'nokogiri', :group => [:KANJIDIC2, :Translate, :URL]

# for URL plugin
gem 'addressable', :group => :URL
gem 'i18n', :group => :URL

# for Translate, URL plugins
gem 'json', :group => [:Translate, :URL]

# for Pinyin plugin
gem 'ruby-pinyin', :group => :Pinyin
gem 'ting', :group => :Pinyin

# for Clock plugin
gem 'tzinfo', :group => :Clock
gem 'iso_country_codes', :group => :Clock

# for EPWING plugin
git 'https://github.com/albel727/rubyeb19.git' do
  gem 'eb', :group => :EPWING
end

# for WebBot plugin
gem 'webrick', :group => :WebBot

# for EDICT plugin
gem 'sequel', :group => :EDICT
gem 'sqlite3', :group => :EDICT

# for Googler plugin
gem 'google-search', :group => :Googler
gem 'htmlentities', :group => :Googler
