
class Throttler
  attr_reader :burst, :rate

  # @param [Integer] burst number of messages to pass without delay
  # before initiating throttling.
  # @param [Numeric] rate number of messages per second for throttled rate.
  # Rate == 0 means no limiting.
  def initialize(burst, rate)
    @burst = burst
    @rate = rate
    @debt_time = Time.now
  end

  def throttle
    if @rate > 0
      now = Time.now
      debt_interval = [0, @debt_time - now].max.to_f
      debt_messages = debt_interval / @rate
      debt_messages += 1
      @debt_time = now + debt_messages * @rate

      if debt_messages > @burst
        sleep((debt_messages-@burst) / @rate)
      end
    end

    yield
  end
end