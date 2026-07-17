class RankingCalculator
  MAX_COMPETITIVE_LAP_SPREAD_MS = 10_000
  COMPETITIVE_FIELD_SIZE = 10..30

  LEVELS = %w[
    iniciante_1 iniciante_2 iniciante_3
    intermediario_1 intermediario_2 intermediario_3
    avancado_1 avancado_2 avancado_3 pro
  ].freeze

  LEVEL_LABELS = {
    "iniciante_1" => "Bronze I", "iniciante_2" => "Bronze II", "iniciante_3" => "Bronze III",
    "intermediario_1" => "Prata I", "intermediario_2" => "Prata II", "intermediario_3" => "Prata III",
    "avancado_1" => "Ouro I", "avancado_2" => "Ouro II", "avancado_3" => "Ouro III",
    "pro" => "Diamante"
  }.freeze

  Race = Data.define(:id, :date, :position, :best_laps_ms, :title)
  HistoryItem = Data.define(
    :race_number, :race_id, :date, :title, :position, :competitive,
    :ranking_points, :mmr_points, :ranking_level, :mmr_level
  )
  Result = Data.define(
    :ranking_level, :ranking_points, :ranking_wins,
    :mmr_level, :mmr_points, :mmr_wins, :history
  )

  def self.points_for(position)
    case position
    when 1 then 10
    when 2 then 7
    when 3 then 6
    when 4..5 then 5
    when 6..10 then 2
    when 11..20 then 1
    else 0
    end
  end

  def self.competitive?(best_laps_ms)
    laps = Array(best_laps_ms)
    return false unless COMPETITIVE_FIELD_SIZE.cover?(laps.size)
    return false if laps.any?(&:nil?)

    laps.max - laps.min <= MAX_COMPETITIVE_LAP_SPREAD_MS
  end

  def self.mmr_eligible?(best_laps_ms)
    (1..30).cover?(Array(best_laps_ms).size)
  end

  def initialize(races)
    @races = races
  end

  def call
    ranking = Progress.new
    mmr = Progress.new
    history = @races.each_with_index.map do |race, index|
      competitive = self.class.competitive?(race.best_laps_ms)
      ranking_points = competitive ? ranking.apply(race.position) : 0
      mmr_points = self.class.mmr_eligible?(race.best_laps_ms) ? mmr.apply(race.position) : 0

      HistoryItem.new(
        race_number: index + 1,
        race_id: race.id,
        date: race.date,
        title: race.title,
        position: race.position,
        competitive: competitive,
        ranking_points: ranking_points,
        mmr_points: mmr_points,
        ranking_level: ranking.level,
        mmr_level: mmr.level
      )
    end

    Result.new(
      ranking_level: ranking.level,
      ranking_points: ranking.progress_points,
      ranking_wins: ranking.wins,
      mmr_level: mmr.level,
      mmr_points: mmr.progress_points,
      mmr_wins: mmr.wins,
      history: history
    )
  end

  class Progress
    attr_reader :level_index, :progress_points, :wins

    def initialize
      @level_index = 0
      @progress_points = 0
      @wins = 0
    end

    def level = LEVELS.fetch(level_index)

    def apply(position)
      return 0 if level == "pro"

      points = RankingCalculator.points_for(position)
      victory = position == 1
      @wins += 1 if victory

      if victory && level_index < LEVELS.index("avancado_1")
        @level_index = LEVELS.index("avancado_1")
        @progress_points = 0
        return 0
      end

      @progress_points += points
      promote_while_eligible
      points
    end

    private

    def promote_while_eligible
      while level_index < LEVELS.index("pro")
        threshold = level == "avancado_3" ? 100 : 10
        break if progress_points < threshold
        break unless wins >= required_wins_for_next_level

        @progress_points -= threshold
        @level_index += 1
      end
    end

    def required_wins_for_next_level
      case level
      when "intermediario_3" then 1
      when "avancado_1" then 2
      when "avancado_2" then 3
      else 0
      end
    end
  end
end