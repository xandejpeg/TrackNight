require "minitest/autorun"
require "time"
require_relative "../../app/services/leaderboard_markdown"

class LeaderboardMarkdownTest < Minitest::Test
  Row = Struct.new(
    :rank, :name, :average_score, :appearances, :average_position, :best_position,
    :wins, :podiums, :best_lap_ms, :profile_codes,
    keyword_init: true
  )

  def test_renders_numbered_rows_and_escapes_names
    row = Row.new(
      rank: 1, name: "Ana | Bia", average_score: 98.5, appearances: 4,
      average_position: 1.25, best_position: 1, wins: 3, podiums: 4,
      best_lap_ms: 61_234, profile_codes: [ "AC", "ACF" ]
    )

    markdown = LeaderboardMarkdown.new([ row ], generated_at: Time.parse("2026-07-18 10:00")).call

    assert_includes markdown, "| 1 | Ana \\| Bia | 98,50 | 4 | 1,25 | P1 | 3 | 4 | 1:01.234 | AC, ACF |"
    assert_includes markdown, "posição relativa"
  end
end