# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Help plugin displays help

require 'rubygems'
require 'bundler/setup'
require 'nokogiri'

require_relative '../../IRCPlugin'

class HelpExport < IRCPlugin
  DESCRIPTION = 'Exports help in externally usable formats.'
  COMMANDS = {
    :export_help_xml => 'exports help in XML format',
  }
  DEPENDENCIES = [:Help]

  def afterLoad
    raise "Configuration error! 'xml' key must be defined." unless @config[:xml]

    @help_plugin = @plugin_manager.plugins[:Help]
  end

  def beforeUnload
    @help_plugin = nil

    nil
  end

  def on_privmsg(msg)
    case msg.bot_command
    when :export_help_xml
      do_export_to_xml(msg)
    end
  end

  def do_export_to_xml(msg)
    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.help do
        xml.plugins do
          @help_plugin.get_all_plugin_documentation.sort_by do |plugin_docs|
            plugin_docs.name
          end.each do |plugin_docs|
            next if plugin_docs.name == :HelpExport

            xml.plugin(:name => plugin_docs.name) do

              unless plugin_docs.description.empty?
                xml.description do
                  recursive_xml_convert(xml, plugin_docs.description)
                end
              end

              unless plugin_docs.commands.empty?
                xml.commands do
                  plugin_docs.commands.sort.each do |command, desc|
                    xml.command(:name => command) do
                      recursive_xml_convert(xml, desc)
                    end
                  end
                end
              end

              unless plugin_docs.dependencies.empty?
                xml.dependencies do
                  plugin_docs.dependencies.sort.each do |dep|
                    xml.dep(dep)
                  end
                end
              end
            end

          end

        end
      end
    end

    File.open(@config[:xml], 'w') do |o|
      o.write(builder.to_xml)
    end

    msg.reply('Exported help as XML.')
  end

  def recursive_xml_convert(xml, catalog)
    if catalog.is_a?(Hash)
      # Description comes from special 'nil' key.
      desc = catalog[nil]
      xml.summary(desc)

      catalog.each_pair do |name, sub_catalog|
        next if name.nil?
        xml.section(:name => name) do
          recursive_xml_convert(xml, sub_catalog)
        end
      end
    else
      desc = catalog
      xml.summary(desc.to_s)
    end
  end

end
