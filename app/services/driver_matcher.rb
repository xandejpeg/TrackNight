# Reconhece pilotos cadastrados (via aliases conhecidos ou nome oficial)
# numa linha de resultado, sem duplicar o piloto por diferença de grafia.
# O fuzzy genérico cobre confusões típicas de OCR (E↔F, I↔L, O↔0, letra
# duplicada/ausente etc.) comparando com o nome oficial de cada driver.
class DriverMatcher
  SIMILARITY_THRESHOLD = 0.72

  def self.match(name, drivers: nil) = new(drivers:).match(name)

  def initialize(drivers: nil)
    @drivers = drivers || Driver.order(:id).to_a
  end

  def match(name)
    normalized = DriverAlias.normalize_name(name)
    return nil if normalized.blank?

    if (found = DriverAlias.find_by(normalized_name: normalized))
      return found.driver
    end

    driver = best_fuzzy_driver(normalized)
    driver&.driver_aliases&.create(name: name) # registra a nova variação
    driver
  end

  private

  def best_fuzzy_driver(normalized)
    @drivers
      .map { |d| [ d, similarity(normalized, DriverAlias.normalize_name(d.name)) ] }
      .select { |(_, score)| score >= SIMILARITY_THRESHOLD }
      .max_by { |(_, score)| score }
      &.first
  end

  # Similaridade 0..1 baseada em distância de Levenshtein normalizada.
  def similarity(a, b)
    return 0.0 if a.blank? || b.blank?
    distance = levenshtein(a, b)
    1.0 - (distance.to_f / [ a.length, b.length ].max)
  end

  def levenshtein(a, b)
    rows = (0..b.length).to_a
    a.each_char.with_index(1) do |ca, i|
      prev = rows[0]
      rows[0] = i
      b.each_char.with_index(1) do |cb, j|
        current = rows[j]
        rows[j] = ca == cb ? prev : [ prev, rows[j - 1], rows[j] ].min + 1
        prev = current
      end
    end
    rows[b.length]
  end
end
