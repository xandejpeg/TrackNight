# Estatísticas de desempenho do Alessandro em sessões confirmadas,
# opcionalmente filtradas por perfil (ACF / AC / todos).
class PerformanceStats
  attr_reader :profile

  def initialize(profile_code: "todos")
    @profile = DriverProfile.find_by(code: profile_code) if profile_code.present? && profile_code != "todos"
  end

  def sessions
    @sessions ||= begin
      scope = RaceSession.confirmed.chronological.includes(:driver_profile, result_entries: :kart)
      scope = scope.where(driver_profile: profile) if profile
      scope.to_a
    end
  end

  # Entradas do Alessandro, em ordem cronológica de sessão.
  def entries
    @entries ||= sessions.filter_map(&:alessandro_entry)
  end

  def sessions_count = sessions.size
  def total_laps = entries.sum { |e| e.laps.to_i }

  def total_track_time_ms
    entries.sum { |e| e.total_time_ms.to_i }
  end

  def best_lap_entry = min_entry(:best_lap_ms)
  def best_s1_entry = min_entry(:s1_ms)
  def best_s2_entry = min_entry(:s2_ms)
  def best_s3_entry = min_entry(:s3_ms)

  def best_speed_entry
    entries.select(&:speed).max_by(&:speed)
  end

  def best_position_entry
    entries.select(&:position).min_by(&:position)
  end

  # Volta ideal: soma dos melhores setores individuais (de sessões distintas).
  def ideal_lap_ms
    parts = [ best_s1_entry&.s1_ms, best_s2_entry&.s2_ms, best_s3_entry&.s3_ms ]
    return nil if parts.any?(&:nil?)
    parts.sum
  end

  def gap_to_ideal_ms
    best = best_lap_entry&.best_lap_ms
    ideal = ideal_lap_ms
    return nil unless best && ideal
    best - ideal
  end

  def average_best_lap_ms
    values = entries.filter_map(&:best_lap_ms)
    values.empty? ? nil : values.sum / values.size
  end

  # Série para gráficos de evolução (uma amostra por sessão, ordem cronológica).
  def evolution
    sessions.filter_map do |s|
      e = s.alessandro_entry
      next unless e
      {
        session_id: s.id,
        label: s.started_at ? s.started_at.strftime("%d/%m %H:%M") : s.title,
        date: s.started_at&.iso8601,
        session_title: s.title,
        profile: s.driver_profile&.code,
        profile_color: s.driver_profile&.color,
        best_ms: e.best_lap_ms,
        s1_ms: e.s1_ms, s2_ms: e.s2_ms, s3_ms: e.s3_ms,
        ideal_ms: e.ideal_lap_ms,
        position: e.position,
        speed: e.speed&.to_f,
        kart: e.kart_number
      }
    end
  end

  # Recordes pessoais e a sessão em que cada um foi cravado (primeira ocorrência).
  def records
    {
      best_lap: record_for(:best_lap_ms),
      s1: record_for(:s1_ms),
      s2: record_for(:s2_ms),
      s3: record_for(:s3_ms)
    }
  end

  # Estatísticas por kart utilizado.
  def kart_stats
    groups = entries.select(&:kart_number).group_by { |e| e.kart_number.to_s.sub(/\A0+(?=\d)/, "") }
    groups.map do |number, list|
      bests = list.filter_map(&:best_lap_ms)
      {
        number: number,
        uses: list.size,
        best_ms: bests.min,
        avg_ms: bests.empty? ? nil : bests.sum / bests.size,
        best_position: list.filter_map(&:position).min,
        sessions: list.map { |e| e.race_session }
      }
    end.sort_by { |k| k[:best_ms] || 10**9 }
  end

  # A entrada bateu recorde pessoal (até aquela sessão, no escopo do filtro)?
  def record_breaking_fields(entry)
    idx = entries.index(entry)
    return [] unless idx
    previous = entries.first(idx)
    %i[best_lap_ms s1_ms s2_ms s3_ms].select do |field|
      value = entry.public_send(field)
      next false unless value
      prior_best = previous.filter_map { |e| e.public_send(field) }.min
      prior_best.nil? ? idx.positive? : value < prior_best
    end
  end

  private

  def min_entry(field)
    entries.select(&field).min_by(&field)
  end

  def record_for(field)
    entry = min_entry(field)
    return nil unless entry
    { value_ms: entry.public_send(field), entry: entry, session: entry.race_session }
  end
end
