class GlobalLeaderboard
  Entry = Data.define(
    :name, :driver_id, :owned, :position, :field_size, :best_lap_ms,
    :profile_code, :session_id, :date
  )
  Row = Data.define(
    :rank, :name, :normalized_name, :aliases, :appearances, :scored_appearances,
    :average_score, :average_position, :best_position, :wins, :podiums,
    :best_lap_ms, :profile_codes, :owned
  )

  def initialize(entries: nil)
    @entries = entries
  end

  def call
    rows = entries.group_by { |entry| identity_key(entry) }.map do |_key, group|
      build_row(group)
    end

    rows.sort_by { |row| sort_key(row) }
      .each_with_index
      .map { |row, index| row.with(rank: index + 1) }
  end

  private

  def entries
    @entries ||= RaceSession.confirmed.prova.chronological
      .where.not(driver_profile_id: nil)
      .includes(:driver_profile, result_entries: :driver)
      .flat_map do |session|
        field_size = session.result_entries.size
        session.result_entries.map do |result|
          Entry.new(
            name: result.driver&.name || result.display_name,
            driver_id: result.driver_id,
            owned: result.driver_id.present? && result.driver_id == session.driver_profile.driver_id,
            position: result.position,
            field_size: field_size,
            best_lap_ms: result.best_lap_ms,
            profile_code: session.driver_profile.code,
            session_id: session.id,
            date: session.started_at
          )
        end
      end
  end

  def identity_key(entry)
    return "owner:#{entry.driver_id}" if entry.owned
    return "driver:#{entry.driver_id}" if entry.driver_id

    "name:#{ParticipantName.normalize(entry.name)}"
  end

  def build_row(group)
    scored = group.select { |entry| valid_finish?(entry) }
    positions = scored.map(&:position)
    scores = scored.map { |entry| relative_score(entry) }
    aliases = group.map(&:name).compact.map(&:strip).reject(&:empty?).uniq

    Row.new(
      rank: nil,
      name: canonical_name(group, aliases),
      normalized_name: ParticipantName.normalize(aliases.first),
      aliases: aliases,
      appearances: group.map(&:session_id).uniq.size,
      scored_appearances: scored.size,
      average_score: scores.empty? ? nil : (scores.sum / scores.size).round(2),
      average_position: positions.empty? ? nil : (positions.sum.to_f / positions.size).round(2),
      best_position: positions.min,
      wins: positions.count(1),
      podiums: positions.count { |position| position <= 3 },
      best_lap_ms: group.filter_map(&:best_lap_ms).min,
      profile_codes: group.filter_map(&:profile_code).uniq.sort,
      owned: group.any?(&:owned)
    )
  end

  def canonical_name(group, aliases)
    owned_name = group.find(&:owned)&.name
    return owned_name unless owned_name.to_s.empty?

    aliases.max_by { |name| [ name.count(" "), name.length ] } || "Piloto sem nome"
  end

  def valid_finish?(entry)
    entry.position.to_i.positive? && entry.field_size.to_i.positive? && entry.position <= entry.field_size
  end

  def relative_score(entry)
    return 100.0 if entry.field_size == 1

    (1.0 - (entry.position - 1).to_f / (entry.field_size - 1)) * 100
  end

  def sort_key(row)
    [
      row.average_score ? -row.average_score : Float::INFINITY,
      -row.wins,
      row.best_position || Float::INFINITY,
      -row.appearances,
      row.best_lap_ms || Float::INFINITY,
      row.normalized_name
    ]
  end
end