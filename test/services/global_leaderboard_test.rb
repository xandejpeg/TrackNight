require "minitest/autorun"
require_relative "../../app/services/participant_name"
require_relative "../../app/services/ranking_calculator"
require_relative "../../app/services/global_leaderboard"

class GlobalLeaderboardTest < Minitest::Test
  Entry = GlobalLeaderboard::Entry

  def test_normalizes_non_utf8_windows_input
    value = "João".encode(Encoding::IBM850)

    assert_equal "JOAO", ParticipantName.normalize(value)
  end

  def test_groups_name_variations_and_keeps_accounts_together
    rows = GlobalLeaderboard.new(entries: [
      entry(name: "João Silva", position: 2, session_id: 1),
      entry(name: "JOAO  SILVA", position: 3, session_id: 2),
      entry(name: "ACF", driver_id: 7, owned: true, position: 4, profile_code: "ACF", session_id: 1),
      entry(name: "AC", driver_id: 7, owned: true, position: 1, profile_code: "AC", session_id: 2)
    ]).call

    assert_equal 2, rows.size
    joao = rows.find { |row| row.normalized_name == "JOAO SILVA" }
    owner = rows.find(&:owned)
    assert_equal 2, joao.appearances
    assert_equal [ "AC", "ACF" ], owner.profile_codes
    assert_equal 2, owner.appearances
  end

  def test_accumulates_official_finishing_points
    rows = GlobalLeaderboard.new(entries: [
      entry(name: "Consistente", position: 4, best_lap_ms: 70_000, session_id: 1),
      entry(name: "Consistente", position: 4, best_lap_ms: 70_000, session_id: 2),
      entry(name: "Segundo", position: 2, best_lap_ms: 50_000, session_id: 3)
    ]).call

    assert_equal [ "Consistente", "Segundo" ], rows.map(&:name)
    assert_equal [ 1, 2 ], rows.map(&:rank)
    assert_equal 10, rows.first.points
    assert_equal 7, rows.last.points
  end

  def test_uses_wins_before_lap_time_to_break_points_tie
    rows = GlobalLeaderboard.new(entries: [
      entry(name: "Vitória", position: 1, best_lap_ms: 70_000, session_id: 1),
      entry(name: "Consistente", position: 4, best_lap_ms: 50_000, session_id: 2),
      entry(name: "Consistente", position: 4, best_lap_ms: 50_000, session_id: 3)
    ]).call

    assert_equal [ "Vitória", "Consistente" ], rows.map(&:name)
    assert_equal [ 10, 10 ], rows.map(&:points)
  end

  def test_keeps_unscored_participant_at_the_bottom
    rows = GlobalLeaderboard.new(entries: [
      entry(name: "Sem posição", position: nil),
      entry(name: "Com posição", position: 10)
    ]).call

    assert_equal "Com posição", rows.first.name
    assert_equal 0, rows.last.points
    assert_equal 0, rows.last.scored_appearances
  end

  private

  def entry(name:, position:, field_size: 20, best_lap_ms: 60_000, driver_id: nil,
            owned: false, profile_code: "ACF", session_id: 1)
    Entry.new(
      name: name, driver_id: driver_id, owned: owned, position: position,
      field_size: field_size, best_lap_ms: best_lap_ms, profile_code: profile_code,
      session_id: session_id, date: nil
    )
  end
end