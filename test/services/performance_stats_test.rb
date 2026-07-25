require "test_helper"

class PerformanceStatsTest < ActiveSupport::TestCase
  FakeEntry = Struct.new(
    :race_session, :kart_number, :best_lap_ms, :speed, :position, :laps,
    :s1_ms, :s2_ms, :s3_ms,
    keyword_init: true
  )

  test "records keep the exact session for lap speed and sectors" do
    lap_session = Struct.new(:id).new(1)
    speed_session = Struct.new(:id).new(2)
    stats = stats_with(
      entry(lap_session, best_lap_ms: 62_000, speed: 79.5, s1_ms: 14_000, s2_ms: 25_000, s3_ms: 23_000),
      entry(speed_session, best_lap_ms: 63_000, speed: 82.9, s1_ms: 14_200, s2_ms: 24_900, s3_ms: 23_100)
    )

    assert_equal lap_session, stats.records[:best_lap][:session]
    assert_equal speed_session, stats.records[:speed][:session]
    assert_equal lap_session, stats.records[:s1][:session]
    assert_equal speed_session, stats.records[:s2][:session]
    assert_equal lap_session, stats.records[:s3][:session]
  end

  test "kart stats keep separate source runs for best lap and maximum speed" do
    lap_session = Struct.new(:id).new(1)
    speed_session = Struct.new(:id).new(2)
    stats = stats_with(
      entry(lap_session, kart_number: "005", best_lap_ms: 62_000, speed: 79.5),
      entry(speed_session, kart_number: "5", best_lap_ms: 63_000, speed: 82.9)
    )

    kart = stats.kart_stats.first

    assert_equal "5", kart[:number]
    assert_equal 2, kart[:uses]
    assert_equal 62_000, kart[:best_ms]
    assert_equal lap_session, kart[:best_run][:session]
    assert_equal 82.9, kart[:max_speed].to_f
    assert_equal speed_session, kart[:fastest_run][:session]
  end

  private

  def stats_with(*entries)
    PerformanceStats.new.tap { |stats| stats.instance_variable_set(:@entries, entries) }
  end

  def entry(session, **attributes)
    FakeEntry.new(**{
      race_session: session,
      kart_number: "1",
      best_lap_ms: nil,
      speed: nil,
      position: 1,
      laps: 10,
      s1_ms: nil,
      s2_ms: nil,
      s3_ms: nil
    }.merge(attributes))
  end
end
