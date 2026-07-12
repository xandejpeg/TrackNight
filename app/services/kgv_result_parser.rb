# Interpreta o texto extraído de um resultado da KGV (layout RACE TRACKS).
#
# Existem três variações de layout de colunas:
#   :a — "... Voltas | Diff | Espaço | Melhor Tempo | Total Tempo | S1 | S2 | S3 | SFSpd"
#   :b — "... Voltas | Melhor Tempo | Total Tempo | Diff | Espaço | S1 | S2 | S3 | SFSpd"
#   :c — "... Voltas | Total Tempo | Melhor Tempo | Diff | Espaço | S1 | S2 | S3 | SFSpd"
#
# O melhor setor NÃO é lido das células destacadas: é calculado depois,
# comparando todos os participantes da sessão.
class KgvResultParser
  VERSION = "1.3.0"

  HEADER_RE = /Resultados\s+de\s+(\w+)\s*[-–]\s*(TOMADA|PROVA|TREINO|CLASSIFICA\w*)\s*(\d+)?\s*[-–]\s*(\d{1,2}:\d{2})/i
  TIME_TOKEN = /\A\d*:?\d{1,2}[.,]\d{2,3}\z/
  SPEED_TOKEN = /\A\d{2,3}[.,]\d\z/
  LAPS_TOKEN = /\A\d{1,2}\z/
  VOLTA_WORD = /\AVoltas?\z/i

  SESSION_TYPES = {
    "TOMADA" => "tomada", "PROVA" => "prova", "TREINO" => "treino"
  }.freeze

  def self.call(text, band_lines: []) = new.call(text, band_lines:)

  def call(text, band_lines: [])
    lines = text.to_s.lines.map(&:strip).reject(&:empty?)
    header = parse_header(lines)
    layout, rows = best_layout_rows(lines)
    fuse_band!(rows, band_lines, layout) if band_lines.any?
    confidence_penalty = rows.count { |r| r[:suspect] }

    {
      venue_hint: detect_venue(lines),
      circuit_hint: detect_circuit(lines),
      session_type: header[:session_type],
      session_number: header[:session_number],
      start_time_text: header[:start_time],
      car_class: header[:car_class],
      column_layout: layout.to_s,
      rows: rows,
      parser_name: name_for_audit,
      parser_version: VERSION,
      row_confidence: rows.empty? ? 0 : (((rows.size - confidence_penalty).to_f / rows.size) * 100).round(1)
    }
  end

  private

  def name_for_audit = self.class.name

  def detect_venue(lines)
    lines.first(4).find { |l| l =~ /GRANJA\s+VIANA|KGV/i } ? "kgv" : nil
  end

  def detect_circuit(lines)
    lines.first(4).each do |l|
      if (m = l.match(/CIRCUITO\s*[-–]?\s*(\d{3})/i))
        return m[1]
      end
    end
    nil
  end

  def parse_header(lines)
    lines.first(6).each do |line|
      if (m = HEADER_RE.match(line))
        return {
          car_class: m[1],
          session_type: SESSION_TYPES.fetch(m[2].upcase[0, 5] == "CLASS" ? "CLASSIFICA" : m[2].upcase, "prova"),
          session_number: m[3]&.to_i,
          start_time: m[4]
        }
      end
    end
    { car_class: nil, session_type: "prova", session_number: nil, start_time: nil }
  end

  # Usa o cabeçalho como pista, mas confirma o layout parseando com todos e
  # ficando com o que produz menos linhas suspeitas/incompletas.
  def best_layout_rows(lines)
    hinted = detect_layout(lines)
    ordered = ([ hinted ] + %i[a b c]).uniq
    parsed = ordered.map { |l| [ l, lines.filter_map { |line| parse_row(line, l) } ] }
    parsed.each_with_index.min_by { |(_, rows), i| [ layout_score(rows), i ] }.first
  end

  def layout_score(rows)
    rows.sum { |r| (r[:suspect] ? 2 : 0) + (r[:best_lap_text].nil? ? 1 : 0) }
  end

  def detect_layout(lines)
    header = lines.find { |l| l =~ /Pos/ && l =~ /Nome/i }
    return :b unless header
    total_idx = header =~ /Total/i
    diff_idx = header =~ /Diff/i
    melhor_idx = header =~ /Melhor/i
    return :b if melhor_idx.nil?
    return :c if total_idx && total_idx < melhor_idx
    return :b if diff_idx.nil?
    diff_idx < melhor_idx ? :a : :b
  end

  def parse_row(line, layout)
    tokens = merge_split_decimals(clean_tokens(line))
    return nil if tokens.size < 3
    return nil unless tokens.first =~ /\A\d{1,2}\z/
    return nil if line =~ /Pos/ && line =~ /Nome/i

    position = tokens.shift.to_i
    kart_number, transponder = extract_kart(tokens)
    return nil if kart_number.nil?

    name_tokens, car_class, points = extract_name_and_class(tokens)
    return nil if name_tokens.empty?

    tail = parse_tail(tokens, layout)

    {
      position:, kart_number:, transponder:,
      name: name_tokens.join(" "),
      car_class:, points:,
      raw_line: line,
      suspect: tail[:suspect]
    }.merge(tail.except(:suspect))
  end

  def clean_tokens(line)
    line.gsub(/[|]/, " ").split(/\s+/).reject { |t| t =~ /\A[_\-=~.,;:]+\z/ }
  end

  # OCR às vezes divide "21.512" em "21.5 12" ou "19:28.689" em "19:28 689" — reagrupa.
  def merge_split_decimals(tokens)
    out = []
    i = 0
    while i < tokens.size
      cur, nxt = tokens[i], tokens[i + 1]
      if cur =~ /\A\d*:?\d{1,2}[.,]\d{1,2}\z/ && nxt =~ /\A\d{1,2}\z/ && "#{cur}#{nxt}" =~ /\A\d*:?\d{1,2}[.,]\d{3}\z/
        out << "#{cur}#{nxt}"
        i += 2
      elsif cur =~ /\A\d{1,2}:\d{2}\z/ && nxt =~ /\A\d{3}\z/
        out << "#{cur}.#{nxt}"
        i += 2
      else
        out << cur
        i += 1
      end
    end
    out
  end

  def extract_kart(tokens)
    kart = tokens.shift
    return [ nil, nil ] unless kart =~ /\A[0O]?\d{1,3}\z/
    kart = kart.tr("O", "0")
    transponder = nil
    if tokens.first =~ /\A[\[\(]?\d{3,7}[\]\)]?\z/
      transponder = tokens.shift.gsub(/[^\d]/, "")
    end
    [ kart, transponder ]
  end

  def extract_name_and_class(tokens)
    class_idx = tokens.index { |t| t =~ /\ARENTAL\z/i }
    return [ [], nil, nil ] if class_idx.nil?

    name_tokens = tokens.shift(class_idx)
    car_class = tokens.shift.upcase
    car_class += " ADV" if tokens.first =~ /\AADV\z/i && tokens.shift

    points = nil
    if name_tokens.last =~ /\A[0O]\z/
      name_tokens.pop
      points = 0
    end
    name_tokens.reject! { |t| t.length == 1 && t =~ /[^A-Z]/ }
    [ name_tokens, car_class, points ]
  end

  # Interpreta os campos numéricos depois da classe, respeitando a ordem
  # de colunas do layout detectado. Campos vazios são tolerados.
  def parse_tail(tokens, layout)
    result = {
      pitstops: nil, laps: nil,
      best_lap_text: nil, total_time_text: nil,
      diff_text: nil, gap_text: nil,
      s1_text: nil, s2_text: nil, s3_text: nil,
      speed_text: nil, suspect: false
    }
    return result if tokens.empty?

    items = group_tail_items(tokens)
    return result.merge(suspect: items.any?) if items.empty?

    # Velocidade: último item no formato "78,1"
    result[:speed_text] = items.pop[:value] if items.last && items.last[:kind] == :speed

    # Voltas: primeiro inteiro simples. Um inteiro pequeno antes dele é pitstops.
    laps_idx = items.index { |i| i[:kind] == :int }
    if laps_idx
      ints = items.select { |i| i[:kind] == :int }
      if ints.size >= 2 && items[laps_idx][:value].to_i <= 3 && items[laps_idx + 1] && items[laps_idx + 1][:kind] == :int
        result[:pitstops] = items.delete_at(laps_idx)[:value]
        laps_idx = items.index { |i| i[:kind] == :int }
      end
      result[:laps] = items.delete_at(laps_idx)[:value].to_i if laps_idx
    end

    # Setores: os três últimos itens de tempo curto (< 60s)
    sector_idxs = items.each_index.select { |ix| items[ix][:kind] == :time && short_time?(items[ix][:value]) }
    if sector_idxs.size >= 3
      s_idx = sector_idxs.last(3)
      result[:s1_text], result[:s2_text], result[:s3_text] = s_idx.map { |ix| items[ix][:value] }
      s_idx.reverse_each { |ix| items.delete_at(ix) }
    else
      result[:suspect] = true if items.any? { |i| i[:kind] == :time }
    end

    assign_middle(items, layout, result)
    result
  end

  def group_tail_items(tokens)
    items = []
    i = 0
    while i < tokens.size
      t = tokens[i]
      if t =~ /\A\d{1,2}\z/ && tokens[i + 1] =~ VOLTA_WORD
        items << { kind: :volta, value: "#{t} #{tokens[i + 1].capitalize}" }
        i += 2
      elsif t =~ SPEED_TOKEN
        items << { kind: :speed, value: t }
        i += 1
      elsif t =~ TIME_TOKEN
        items << { kind: :time, value: repair_time(t.tr(",", ".")) }
        i += 1
      elsif t =~ LAPS_TOKEN
        items << { kind: :int, value: t }
        i += 1
      else
        i += 1 # ruído de OCR
      end
    end
    items
  end

  # OCR às vezes perde o dois-pontos: "102.557" → "1:02.557".
  def repair_time(value)
    if (m = value.match(/\A(\d)(\d{2})\.(\d{3})\z/)) && m[2].to_i < 60
      "#{m[1]}:#{m[2]}.#{m[3]}"
    else
      value
    end
  end

  def short_time?(value)
    ms = LapTime.parse_ms(value)
    ms.present? && ms.between?(5_000, 59_999)
  end

  def long_time?(value)
    ms = LapTime.parse_ms(value)
    ms.present? && ms >= 120_000
  end

  # Depois de remover voltas, setores e velocidade sobram:
  #   layout :a → [diff, espaço, melhor, total]  (melhor/total no fim)
  #   layout :b → [melhor, total, diff, espaço]  (melhor/total no início)
  #   layout :c → [total, melhor, diff, espaço]  (total antes de melhor)
  def assign_middle(items, layout, result)
    times = items.select { |i| i[:kind] == :time }
    voltas = items.select { |i| i[:kind] == :volta }

    case layout
    when :b
      result[:best_lap_text] = times.shift&.dig(:value)
      result[:total_time_text] = times.shift&.dig(:value)
    when :c
      result[:total_time_text] = times.shift&.dig(:value)
      result[:best_lap_text] = times.shift&.dig(:value)
    else
      result[:total_time_text] = times.pop&.dig(:value)
      result[:best_lap_text] = times.pop&.dig(:value)
    end
    leftovers = voltas.map { |v| v[:value] } + times.map { |t| t[:value] }
    result[:diff_text] = leftovers[0]
    result[:gap_text] = leftovers[1]

    # sanity: total deve ser maior que melhor volta
    if result[:best_lap_text] && result[:total_time_text]
      best = LapTime.parse_ms(result[:best_lap_text])
      total = LapTime.parse_ms(result[:total_time_text])
      result[:suspect] = true if best && total && total < best
    end
  end

  # ------------------------------------------------------------------
  # Fusão por votação da linha destacada (retângulo vermelho).
  # Cada variante de OCR da faixa produz uma leitura candidata; o valor de
  # cada campo é escolhido por maioria entre os candidatos válidos, com
  # verificação cruzada (setores ≤ 60s, melhor volta ≥ volta ideal).
  # ------------------------------------------------------------------

  TIME_TEXT_RE = /\A(?:\d{1,2}:)?\d{1,2}\.\d{3}\z/

  def fuse_band!(rows, band_lines, layout)
    candidates = band_lines.filter_map { |l| parse_band_row(l, layout) }
    return if candidates.size < 2

    target_idx = find_band_target(rows, candidates)
    primary = target_idx ? rows[target_idx] : nil
    fused = fuse_fields(primary, candidates)
    return unless fused

    if target_idx
      rows[target_idx] = fused
    else
      gap = missing_position(rows)
      fused[:position] = gap if gap
      rows << fused
      rows.sort_by! { |r| r[:position] || 99 }
    end
  end

  # Se a sequência de posições tem exatamente uma lacuna, ela pertence à linha destacada.
  def missing_position(rows)
    positions = rows.map { |r| r[:position] }.compact.sort
    return nil if positions.empty?
    gaps = (positions.first..positions.last).to_a - positions
    gaps.size == 1 ? gaps.first : nil
  end

  def pre_clean_band_line(line)
    line.gsub(/[|_()\[\]{}!»«§©®]/, " ").gsub(/\s{2,}/, " ").strip
  end

  # A posição e os números da linha destacada costumam sair corrompidos
  # ("1f" = 16, "1fi" = 16, "Th" = 16); repara dígitos confundidos nos tokens
  # numéricos antes do parse.
  def parse_band_row(line, layout)
    tokens = pre_clean_band_line(line).split(/\s+/)
    return nil if tokens.empty?
    drop_leading_junk!(tokens)
    class_idx = tokens.index { |t| t =~ /\AR?[EF]NTA[LI1]?\z/i }
    tokens[0] = repair_digits(tokens[0])
    tokens[1] = repair_digits(tokens[1]) if tokens[1]
    if class_idx
      tokens[class_idx] = "RENTAL"
      ((class_idx + 1)...tokens.size).each do |i|
        tokens[i] = repair_digits(tokens[i]) if tokens[i] =~ /\A[\dIlTtoOfhi.,:;]+\z/ && tokens[i] =~ /[\d]/
      end
    end
    row = parse_row(tokens.join(" "), layout)
    positional_sectors!(row, tokens) if row
    row
  end

  # As bordas do retângulo vermelho viram caracteres-fantasma no início da
  # linha ("il 16 015..."). Descarta o primeiro token quando ele não é um
  # número reparável — ou quando o padrão "posição + kart de 3 dígitos" começa
  # logo depois dele.
  def drop_leading_junk!(tokens)
    2.times do
      break if tokens.size < 3
      t0 = repair_digits(tokens[0].to_s)
      if t0 !~ /\A\d{1,3}\z/
        tokens.shift
      elsif repair_digits(tokens[1].to_s) =~ /\A\d{1,2}\z/ && repair_digits(tokens[2].to_s) =~ /\A\d{3}\z/
        tokens.shift
      else
        break
      end
    end
  end

  # Na linha destacada, os três tokens antes da velocidade final são S1 S2 S3.
  # Essa regra posicional é mais confiável que a heurística geral quando a
  # linha está corrompida.
  def positional_sectors!(row, tokens)    
    spd_idx = tokens.rindex { |t| t =~ SPEED_TOKEN }
    return unless spd_idx && spd_idx >= 3

    s1, s2, s3 = tokens[(spd_idx - 3)...spd_idx].map { |t| normalize_sector(t) }
    row[:s1_text] = s1
    row[:s2_text] = s2
    row[:s3_text] = s3
  end

  def normalize_sector(token)
    t = repair_time(token.to_s.tr(",", "."))
    return nil unless t =~ /\A\d{1,2}\.\d{3}\z/
    ms = LapTime.parse_ms(t)
    ms && ms.between?(5_000, 59_999) ? t : nil
  end

  def repair_digits(token)
    repaired = token.gsub("fi", "6").gsub(/[fh]/, "6").gsub(/[IlT]/, "1")
                    .gsub(/[oO]/, "0").gsub(/[Ss]/, "5").gsub("A", "4")
                    .gsub(";", ":").sub(/[.,]+\z/, "")
    repaired =~ /\A[\d.,:]+\z/ ? repaired : token
  end

  def find_band_target(rows, candidates)
    # 1º critério: nome mais parecido com o votado na faixa (a linha destacada
    # é de um piloto específico; similaridade máxima evita homônimos parciais)
    band_name = vote_name(candidates)
    if band_name
      scored = rows.each_index.map { |i| [ i, name_similarity(rows[i][:name], band_name) ] }
      best_i, score = scored.max_by(&:last)
      return best_i if score && score >= 0.75
    end
    # 2º: kart + posição, desde que o nome não conflite
    kart = majority(candidates.map { |c| c[:kart_number] }.compact)
    pos = majority(candidates.map { |c| c[:position] }.compact)
    idx = rows.index { |r| kart && r[:kart_number] == kart }
    idx ||= rows.index { |r| pos && r[:position] == pos }
    return nil if idx && band_name && rows[idx][:name] && !names_compatible?(rows[idx][:name], band_name)
    idx
  end

  # Compara nomes tolerando confusões de OCR (E↔F, D↔N, R↔B...).
  def names_compatible?(a, b)
    name_similarity(a, b) >= 0.6
  end

  def name_similarity(a, b)
    na, nb = [ a, b ].map { |n| n.to_s.upcase.gsub(/[^A-Z]/, "") }
    return 0.0 if na.length < 5 || nb.length < 5
    len = [ na.length, nb.length ].min
    (0...len).count { |i| na[i] == nb[i] }.to_f / len
  end

  def majority(values)
    return nil if values.empty?
    tally = values.tally
    max = tally.values.max
    values.find { |v| tally[v] == max }
  end

  # Escolhe o valor de cada campo por maioria entre candidatos válidos.
  def fuse_fields(primary, candidates)
    pool = candidates + [ primary ].compact
    fused = {
      position: vote(pool, :position) { |v| v.is_a?(Integer) && v.between?(1, 40) },
      kart_number: vote(pool, :kart_number) { |v| v.to_s =~ /\A\d{1,3}\z/ },
      transponder: vote(pool, :transponder) { |v| v.to_s =~ /\A\d{3,7}\z/ },
      name: vote_name(pool),
      car_class: vote(pool, :car_class) { |v| v.present? },
      points: vote(pool, :points) { |v| !v.nil? },
      pitstops: vote(pool, :pitstops) { |v| !v.nil? },
      laps: vote(pool, :laps) { |v| v.is_a?(Integer) && v.between?(1, 99) },
      best_lap_text: vote(pool, :best_lap_text) { |v| valid_time?(v) },
      total_time_text: vote(pool, :total_time_text) { |v| valid_time?(v) },
      diff_text: vote(pool, :diff_text) { |v| valid_diff?(v) },
      gap_text: vote(pool, :gap_text) { |v| valid_diff?(v) },
      s1_text: vote(pool, :s1_text) { |v| valid_sector?(v) },
      s2_text: vote(pool, :s2_text) { |v| valid_sector?(v) },
      s3_text: vote(pool, :s3_text) { |v| valid_sector?(v) },
      speed_text: vote(pool, :speed_text) { |v| v.to_s =~ /\A\d{2,3}[.,]\d\z/ },
      raw_line: primary&.dig(:raw_line) || candidates.first[:raw_line],
      fused_from_band: true
    }
    reconcile_best_lap!(fused, pool)
    reconcile_sectors!(fused, pool)
    reconcile_total!(fused, pool)
    fused[:suspect] = fused[:best_lap_text].nil? || fused[:name].nil?
    fused[:position] ? fused : nil
  end

  def vote(pool, field, &valid)
    values = pool.map { |c| c[field] }.select { |v| !v.nil? && valid.call(v) }
    majority(values)
  end

  # Nomes são votados na forma normalizada (OCR confunde E↔F etc.);
  # devolve a grafia mais frequente do grupo vencedor.
  def vote_name(pool)
    names = pool.map { |c| c[:name] }.compact.select { |n| n.gsub(/[^A-Za-zÀ-ú]/, "").length >= 5 }
    return nil if names.empty?
    groups = names.group_by { |n| n.upcase.gsub(/[^A-Z]/, "") }
    winner = groups.values.max_by(&:size)
    majority(winner)
  end

  def valid_time?(v)
    return false unless v.to_s =~ TIME_TEXT_RE
    if (m = v.to_s.match(/\A(\d{1,2}):(\d{1,2})\./))
      return false if m[2].to_i >= 60
    end
    LapTime.parse_ms(v).present?
  end

  def valid_sector?(v)
    return false unless valid_time?(v)
    LapTime.parse_ms(v) < 60_000
  end

  def valid_diff?(v)
    v.to_s =~ /\A\d+ Voltas?\z/i || valid_time?(v)
  end

  # A melhor volta nunca é menor que qualquer setor individual. Só procura
  # outro candidato quando o valor votado é impossível; a volta ideal (soma
  # dos setores) serve apenas para marcar suspeita.
  def reconcile_best_lap!(fused, pool)
    sectors = [ fused[:s1_text], fused[:s2_text], fused[:s3_text] ].filter_map { |t| LapTime.parse_ms(t) }
    return if sectors.empty?

    max_sector = sectors.max
    best = LapTime.parse_ms(fused[:best_lap_text])
    return if best && best >= max_sector

    plausible = pool.map { |c| c[:best_lap_text] }
                    .select { |t| valid_time?(t) }
                    .map { |t| [ t, LapTime.parse_ms(t) ] }
                    .select { |_, ms| ms >= max_sector && ms < max_sector * 3 }
    fused[:best_lap_text] = plausible.min_by { |_, ms| ms }&.first || fused[:best_lap_text]
  end

  # A volta ideal (S1+S2+S3) nunca excede a melhor volta: os setores exibidos
  # são os melhores individuais da sessão. Quando a soma dos setores votados
  # viola isso, procura a combinação de candidatos mais votada que respeite.
  def reconcile_sectors!(fused, pool)
    best = LapTime.parse_ms(fused[:best_lap_text])
    return unless best

    tallies = %i[s1_text s2_text s3_text].map do |f|
      values = pool.map { |c| c[f] }.select { |v| valid_sector?(v) }
      values.tally.sort_by { |_, n| -n }.first(8)
    end
    return if tallies.any?(&:empty?)

    current = %i[s1_text s2_text s3_text].map { |f| LapTime.parse_ms(fused[f]) }
    return if current.none?(&:nil?) && current.sum <= best + 100

    combos = tallies[0].product(tallies[1], tallies[2])
    valid = combos.select do |combo|
      sum = combo.sum { |(v, _)| LapTime.parse_ms(v) }
      sum <= best + 100 && sum >= (best * 0.85).round
    end
    winner = valid.max_by { |combo| combo.sum { |(_, n)| n } }
    return unless winner

    fused[:s1_text], fused[:s2_text], fused[:s3_text] = winner.map(&:first)
  end

  # O tempo total nunca é menor que a melhor volta — e, como toda volta dura
  # pelo menos a melhor volta, nunca é menor que melhor × voltas.
  def reconcile_total!(fused, pool)
    best = LapTime.parse_ms(fused[:best_lap_text])
    return if best.nil?

    laps = fused[:laps].to_i
    minimum = laps.positive? ? best * laps : best
    total = LapTime.parse_ms(fused[:total_time_text])
    return if total && total >= minimum

    # O total às vezes cai em outro campo de tempo do candidato (OCR desloca
    # colunas); procura em todos eles.
    plausible = pool.flat_map { |c| c.values_at(:total_time_text, :best_lap_text, :diff_text, :gap_text) }
                    .select { |t| valid_time?(t) && LapTime.parse_ms(t) >= minimum }
    fused[:total_time_text] = majority(plausible) if plausible.any?
  end
end
