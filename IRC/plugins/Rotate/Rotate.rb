# encoding: utf-8

require_relative '../../IRCPlugin'

class Rotate < IRCPlugin
  DESCRIPTION = 'Rotate any unicode string in both directions.'

  Dependencies = [ :StorageYAML ]

  Commands = {
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

    number = msg.tail.split(" ")[0].to_i

    original = msg.tail.split(" ")
    original.delete_at(0)
    original = original.join

    return unless number && original.length > 0

    msg.reply( original.each_char.map{ |o| o.unpack('U').map{ |c|
      if( c >= LOWER_BOUND && c <= UPPER_BOUND )
        new = c + number
        until new >= LOWER_BOUND && new <= UPPER_BOUND
          if( new < LOWER_BOUND ) then new += ( UPPER_BOUND - LOWER_BOUND ) end
          if( new > UPPER_BOUND ) then new -= ( UPPER_BOUND - LOWER_BOUND ) end
        end
        c = new
      end
    }.pack('U') }.join )
  end

  UPPER_BOUND = 57343
  LOWER_BOUND = 0
end
