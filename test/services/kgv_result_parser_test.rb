require "minitest/autorun"
require "active_support/core_ext/object/blank"
require_relative "../../app/services/lap_time"
require_relative "../../app/services/kgv_result_parser"

class KgvResultParserTest < Minitest::Test
  HEADER = "Pos No. Nome Classe Voltas Melhor Tempo Total Tempo Diff Espaco S1 S2 S3 SFSpd"

  def test_accepts_position_markers_and_missing_position_token
    rows = parse_rows(
      "8 053 MIGUEL ANGELO RENTAL 14 1:04.364 16:29.603 1:04.350 11.416 14.855 25.554 23.167 76,1",
      "] 061 RAFAEL TOREZANI RENTAL 13 1:02.608 15:40.252 1 Volta 1 Volta 14.651 25.137 22.768 77,9",
      "10 047 EVERTON LUIZ RENTAL 13 1:04.665 16:04.010 1 Volta 23.758 14.896 25.950 23.599 78,6",
      "13° 020 IGOR DUBOIS RENTAL 13 1:05.748 16:07.127 1 Volta 1.911 15.079 26.863 23.511 76,4"
    )

    assert_equal [ 8, 9, 10, 13 ], rows.map { |row| row[:position] }
    assert_equal "RAFAEL TOREZANI", rows[1][:name]
  end

  def test_repairs_misread_position_from_neighboring_sequence
    rows = parse_rows(
      "8 015 LUCAS ATTOLINI RENTAL 17 1:02.595 19:22.173 48.937 7.392 14.668 24.989 22.560 85,1",
      "3 051 MURILO SILVA RENTAL 17 1:01.414 19:24.498 51.262 2.325 14.222 24.716 22.099 85,0",
      "10 007 ALVARO LOPES JR RENTAL 17 1:01.131 19:24.935 51.699 0.437 14.090 24.893 21.894 86,2",
      "19 002 BRUNO HODGE RENTAL 14 1:04.197 18:44.070 3 Voltas 26.690 14.397 25.749 22.962 77,5",
      "29 033 CELSO GOMES RENTAL 14 1:09.160 18:47.399 3 Voltas 3.329 15.372 27.986 23.893 74,8",
      "21 007 VITOR TEIXEIRA RENTAL 14 1:07.020 19:02.093 3 Voltas 14.694 15.233 26.644 23.744 74,7"
    )

    assert_equal [ 8, 9, 10, 19, 20, 21 ], rows.map { |row| row[:position] }
  end

  def test_accepts_letter_s_as_position_five
    row = parse_rows(
      "S 064 [240388] JEFFERSON VIEIRA RENTAL 11 1:27,.556 18:50.757 1 Volta 1 Volta 34.486 31.827 67.4 19.802"
    ).first

    assert_equal 5, row[:position]
    assert_equal "JEFFERSON VIEIRA", row[:name]
  end

  def test_accepts_letter_u_as_leading_kart_zero
    row = parse_rows(
      "17) U21 LEONARDO CUSTUDIO RENTAL 14 1:07.003 19:50.965 1 Volta 1.996 15.208 26.582 24.270 72,9"
    ).first

    assert_equal 17, row[:position]
    assert_equal "021", row[:kart_number]
  end

  def test_cleans_attached_punctuation_without_shifting_times
    row = parse_rows(
      "10 059 ROBERTA MILSONE RENTAL 10 1:30.617 =19:38.169 2 Voltas 17.875 36.016 32.068 21.647 60,1"
    ).first

    assert_equal "1:30.617", row[:best_lap_text]
    assert_equal "19:38.169", row[:total_time_text]
    assert_equal [ "36.016", "32.068", "21.647" ], row.values_at(:s1_text, :s2_text, :s3_text)
  end

  def test_uses_alternate_sector_order_from_header
    header = "Pos No. Nome Classe Voltas Melhor Tempo Total Tempo Diff Espaco S2 S3 SFSpd S1"
    row = KgvResultParser.call([
      header,
      "2 039 KAYKY OLIVEIRA RENTAL 12 1:22.035 18:52.758 0.042 0.042 32.773 29.487 68,9 19.572"
    ].join("\n"))[:rows].first

    assert_equal "68,9", row[:speed_text]
    assert_equal [ "19.572", "32.773", "29.487" ], row.values_at(:s1_text, :s2_text, :s3_text)
  end

  def test_repairs_lowercase_lap_digits_and_three_digit_artifact
    rows = parse_rows(
      "7 065 FABIANO DOMINGUES RENTAL i4 1:06.800 18:04.691 2 Voltas 1.755 15.541 26.168 23.924 76,7",
      "22 004 VICTOR TENG RENTAL 135 1:04.162 19:47.411 2 Voltas 31.125 14.938 25.887 23.267 77,1"
    )

    assert_equal [ 14, 13 ], rows.map { |row| row[:laps] }
  end

  def test_extracts_transponder_with_mismatched_delimiter
    row = parse_rows(
      "1 034 [185897} RICARDO ALVES RENTAL 12 1:24.467 18:52.716 33.699 30.182 19.975 67,5"
    ).first

    assert_equal "185897", row[:transponder]
    assert_equal "RICARDO ALVES", row[:name]
  end

  private

  def parse_rows(*lines)
    KgvResultParser.call(([ HEADER ] + lines).join("\n"))[:rows]
  end
end