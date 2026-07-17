class ProfileRanking
  def initialize(profile)
    @profile = profile
  end

  def call
    RankingCalculator.new(races).call
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