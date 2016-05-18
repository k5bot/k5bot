# encoding: utf-8

# Google Token Generator.
# Thanks to @helen5106 and @tehmaestro and few other cool guys
# at https://github.com/Stichoza/google-translate-php/issues/32
#

class Translate
module GoogleTokenGenerator
  extend self

  def generate_token(text)
    tl(text)
  end

  private

  def tl(a)
    b = tkk[0]
    d = []
    e = 0
    f = 0

    while f < a.length do
      g = char_code_at(a, f)
      if 128 > g
        d[e] = g
        e += 1
      else
        if 2048 > g
          d[e] = g >> 6 | 192
          e += 1
        else
          if 55296 == (g & 64512) && f + 1 < a.length && 56320 == (char_code_at(a, (f+1)) & 64512)
            f += 1
            g = 65536 + ((g & 1023) << 10) + (char_code_at(a, f) & 1023)
            d[e] = g >> 18 | 240
            e += 1
            d[e] = g >> 12 & 63 | 128
            e += 1
          else
            d[e] = g >> 12 | 224
            e += 1
            d[e] = g >> 6 & 63 | 128
            e += 1
          end
        end
        d[e] = g & 63 | 128
        e += 1
      end
      f += 1
    end

    a = b
    e = 0

    while e < d.length do
      a += d[e]
      a = rl(a, '+-a^+6')
      e += 1
    end

    a = rl(a, '+-3^+b+-f')
    a ^= tkk[1]
    a = (a & 2147483647) + 2147483648 if 0 > a
    a %= 10 ** 6

    ("#{ a }.#{ a ^ b }")
  end

  def tkk
    [406398, (561666268 + 1526272306)]
  end

  def rl(a, b)
    c = 0
    while c < (b.length - 2)
      d = b[c+2]
      d = (d >= 'a') ? char_code_at(d, 0) - 87 : d.to_i
      d = (b[c+1] ==  '+') ? shr32(a, d) : a << d
      a = (b[c] == '+') ? (a + d & 4294967295) : a ^ d
      c += 3
    end
    a
  end

  def shr32(x, bits)
    return x if bits.to_i <= 0
    return 0 if bits.to_i >= 32

    bin = x.to_i.to_s(2) # to binary
    l = bin.length
    if l > 32
      bin = bin[(l - 32), 32]
    elsif l < 32
      bin = bin.rjust(32, '0')
    end

    bin = bin[0, (32 - bits)]

    (bin.rjust(32, '0')).to_i(2)
  end

  def char_code_at(str, index)
    char = str[index]
    v = char.unpack('U*')
    v[0]
  end
end
end