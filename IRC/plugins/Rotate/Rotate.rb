# encoding: utf-8

require 'IRC/IRCPlugin'

class Rotate < IRCPlugin
  DESCRIPTION = 'Rotate any unicode string in both directions.'

  DEPENDENCIES = [:StorageYAML]

  COMMANDS = {
    :rotate => 'Rotate unicode string by positive or negative number.',
  }

  def on_privmsg(msg)
    return unless msg.tail
    case msg.bot_command
      when :rot13
        text = msg.tail
        text = do_rotate(text, ROT13_COMMANDS)
        msg.reply(text)
      when :rotate
        number, *text = msg.tail.split(' ')
        number = number.to_i
        text = text.join
        return unless number != 0 && text.length > 0

        text = do_rotate(text, [[number, UNICODE_BMP_LOWER, UNICODE_BMP_UPPER]])
        msg.reply(text)
    end
  end

  def do_rotate(text, commands)
    text = text.unpack('U*')

    commands.each do |number, lower_bound, upper_bound|
      upper_bound += 1
      text.map! do |c|
        next c unless c >= lower_bound && c < upper_bound
        lower_bound + (c + number - lower_bound) % (upper_bound - lower_bound)
      end
    end

    text.pack('U*')
  end

  private

  ROT13_COMMANDS = [
      [13, *'az'.unpack('U*')],
      [13, *'AZ'.unpack('U*')],
  ]

  UNICODE_BMP_LOWER = 0
  UNICODE_BMP_UPPER = 0xDFFF
end
