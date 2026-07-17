require "minitest/autorun"
require_relative "../../app/services/ranking_calculator"

class RankingCalculatorTest < Minitest::Test
  def test_public_tier_names
    assert_equal "Bronze I", RankingCalculator::LEVEL_LABELS.fetch("iniciante_1")
    assert_equal "Prata III", RankingCalculator::LEVEL_LABELS.fetch("intermediario_3")
    assert_equal "Ouro III", RankingCalculator::LEVEL_LABELS.fetch("avancado_3")
    assert_equal "Diamante", RankingCalculator::LEVEL_LABELS.fetch("pro")
  end

  def test_points_by_finishing_position
    expected = {
      1 => 10, 2 => 7, 3 => 6, 4 => 5, 5 => 5,
      6 => 2, 10 => 2, 11 => 1, 20 => 1, 21 => 0, 30 => 0
    }

    expected.each do |position, points|
      assert_equal points, RankingCalculator.points_for(position)
    end
  end

  def test_competitive_race_requires_every_lap_inside_the_ten_second_window
    assert RankingCalculator.competitive?([ 60_000 ] * 9 + [ 70_000 ])
    refute RankingCalculator.competitive?([ 60_000 ] * 9 + [ 70_001 ])
    refute RankingCalculator.competitive?([ 60_000 ] * 9 + [ nil ])
    refute RankingCalculator.competitive?([ 60_000 ] * 9)
  end

  def test_casual_race_only_scores_mmr
    result = RankingCalculator.new([ race(position: 4, field_size: 9) ]).call

    assert_equal 0, result.ranking_points
    assert_equal 5, result.mmr_points
    refute result.history.first.competitive
  end

  def test_first_competitive_win_jumps_to_advanced_without_ten_points
    result = RankingCalculator.new([ race(position: 1) ]).call

    assert_equal "avancado_1", result.ranking_level
    assert_equal 0, result.ranking_points
    assert_equal 1, result.ranking_wins
  end

  def test_advanced_levels_require_two_and_three_total_wins
    result = RankingCalculator.new([
      race(position: 1),
      race(position: 1),
      race(position: 1)
    ]).call

    assert_equal "avancado_3", result.ranking_level
    assert_equal 0, result.ranking_points
    assert_equal 3, result.ranking_wins
  end

  def test_advanced_three_requires_one_hundred_points_for_pro
    races = [ race(position: 1), race(position: 1), race(position: 1) ]
    races.concat(Array.new(10) { race(position: 1) })
    races << race(position: 1)

    result = RankingCalculator.new(races).call

    assert_equal "pro", result.ranking_level
    assert_equal 0, result.ranking_points
    assert_equal 13, result.ranking_wins
    assert_equal 0, result.history.last.ranking_points
  end

  private

  def race(position:, field_size: 10)
    @race_id = @race_id.to_i + 1
    RankingCalculator::Race.new(
      id: @race_id,
      date: nil,
      position: position,
      best_laps_ms: Array.new(field_size, 60_000),
      title: "Prova #{@race_id}"
    )
  end
end