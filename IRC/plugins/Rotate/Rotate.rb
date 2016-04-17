# encoding: utf-8

require_relative '../../IRCPlugin'

class Rotate < IRCPlugin
  DESCRIPTION = 'Rotate any unicode string in both directions.'

  DEPENDENCIES = [:StorageYAML]

  COMMANDS = {
    :rotate => 'Rotate unicode string by positive or negative number.',
  }

  def on_privmsg(msg)
    case msg.bot_command
      when :rotate
        rotate(msg)
    end
  end

  def rotate(msg)
    return unless msg.tail

    text = msg.tail.split(' ')
    number = text.shift
    number = number.to_i
    text = text.join

    return unless number != 0 && text.length > 0

    rotated = text.unpack('U*').map do |c|
      next unless c >= LOWER_BOUND && c < UPPER_BOUND
      LOWER_BOUND + (c + number - LOWER_BOUND) % (UPPER_BOUND - LOWER_BOUND)
    end.compact.pack('U*')

    msg.reply(rotated)
  end

  UPPER_BOUND = 0xE000
  LOWER_BOUND = 0
end
