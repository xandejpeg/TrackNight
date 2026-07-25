class ProfileRanking
  def initialize(profile)
    @profile = profile
  end

  def call
    result = RankingCalculator.new(races).call
    return result if profile.ranking_override.blank?

    result.with(ranking_level: profile.ranking_override)
  end

  private

  attr_reader :profile

  def races
    RaceSession.confirmed.prova.chronological
      .where(driver_profile: profile)
      .includes(:result_entries)
      .filter_map do |session|
        entry = session.alessandro_entry
        next unless entry

        RankingCalculator::Race.new(
          id: session.id,
          date: session.started_at,
          position: entry.position,
          best_laps_ms: session.result_entries.map(&:best_lap_ms),
          title: session.title
        )
      end
  end
end