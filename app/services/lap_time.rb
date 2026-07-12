# Conversão de tempos de volta entre texto ("1:02.168", "59.440", "18:07.073")
# e milissegundos. Valores não conversíveis (ex.: "1 Volta") retornam nil.
module LapTime
  TIME_RE = /\A(?:(\d+):)?(\d{1,2})[.,](\d{1,3})\z/

  module_function

  def parse_ms(text)
    return nil if text.blank?
    m = TIME_RE.match(text.to_s.strip)
    return nil unless m
    minutes = m[1].to_i
    seconds = m[2].to_i
    millis  = m[3].ljust(3, "0").to_i
    (minutes * 60_000) + (seconds * 1_000) + millis
  end

  def format(ms, precision: 3)
    return "—" if ms.nil?
    total_seconds, millis = ms.divmod(1000)
    minutes, seconds = total_seconds.divmod(60)
    frac = format_fraction(millis, precision)
    if minutes.positive?
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}.#{frac}"
    else
      "#{seconds}.#{frac}"
    end
  end

  def format_fraction(millis, precision)
    millis.to_s.rjust(3, "0")[0, precision]
  end

  def format_delta(ms)
    return "—" if ms.nil?
    sign = ms.negative? ? "-" : "+"
    "#{sign}#{format(ms.abs)}"
  end
end
