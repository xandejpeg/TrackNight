class LeaderboardMarkdown
  def initialize(rows, generated_at: Time.now)
    @rows = rows
    @generated_at = generated_at
  end

  def call
    lines = [
      "# Ranking geral TrackNight",
      "",
      "Gerado em #{@generated_at.strftime('%d/%m/%Y às %H:%M')}.",
      "",
      "Critério: média da posição relativa em cada grid, seguida por vitórias, melhor posição e número de encontros. " \
        "Tempos absolutos são informativos e não ordenam pistas ou traçados diferentes.",
      "",
      "| # | Piloto | Nota | Corridas | Média pos. | Melhor | Vitórias | Pódios | Melhor volta | Contas |",
      "|---:|---|---:|---:|---:|---:|---:|---:|---:|---|"
    ]

    @rows.each do |row|
      lines << [
        "| #{row.rank}",
        escape(row.name),
        format_number(row.average_score),
        row.appearances,
        format_number(row.average_position),
        row.best_position ? "P#{row.best_position}" : "—",
        row.wins,
        row.podiums,
        format_lap(row.best_lap_ms),
        row.profile_codes.empty? ? "—" : row.profile_codes.join(", ")
      ].join(" | ") + " |"
    end

    lines.join("\n") + "\n"
  end

  private

  def escape(value) = value.to_s.gsub("|", "\\|")
  def format_number(value) = value ? format("%.2f", value).tr(".", ",") : "—"

  def format_lap(milliseconds)
    return "—" unless milliseconds

    minutes, remainder = milliseconds.divmod(60_000)
    seconds, millis = remainder.divmod(1_000)
    format("%d:%02d.%03d", minutes, seconds, millis)
  end
end