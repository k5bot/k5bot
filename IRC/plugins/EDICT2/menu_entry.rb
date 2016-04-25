# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

class EDICT2
  class MenuEntry < (Menu::MenuNodeText)
    def do_reply(msg, entry)
      # split on slashes before entry numbers
      msg.reply(
          LayoutableText::SplitJoined.new(
              '/',
              entry.raw.split(/\/(?=\s*\(\d+\))/, -1),
          ),
      )
    end
  end
end