# Reconhece o piloto Alessandro Chiarelli (e variações de grafia) numa
# linha de resultado, sem duplicar o piloto por diferença de escrita.
class DriverMatcher
  FUZZY_FIRST = "ALESSANDRO"
  FUZZY_LAST_PREFIX = "CHIAREL"
  # Tolerante a confusões de OCR (E↔F, D↔N, A↔S, L↔I, S duplicado etc.)
  OCR_FIRST_RE = /\b[AS]?[LI][EF]SS?\s?A?N+[DN]R[OA]?\b/
  OCR_LAST_RE = /\bCH.{0,2}AR|\bCH[ILT]?[AGO]?RE/

  def self.match(name) = new.match(name)

  def match(name)
    normalized = DriverAlias.normalize_name(name)
    return nil if normalized.blank?

    if (found = DriverAlias.find_by(normalized_name: normalized))
      return found.driver
    end

    exact_fuzzy = normalized.include?(FUZZY_FIRST) &&
                  normalized.split.any? { |w| w.start_with?(FUZZY_LAST_PREFIX) }
    ocr_fuzzy = normalized =~ OCR_FIRST_RE && normalized =~ OCR_LAST_RE

    if exact_fuzzy || ocr_fuzzy
      driver = Driver.find_by(slug: "alessandro-chiarelli")
      if driver
        driver.driver_aliases.create(name: name) # registra a nova variação
        return driver
      end
    end

    nil
  end
end
