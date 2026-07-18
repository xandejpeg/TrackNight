namespace :ranking do
  desc "Gera docs/ranking_geral.md com todos os pilotos encontrados"
  task export_markdown: :environment do
    rows = GlobalLeaderboard.new.call
    output = Rails.root.join("docs", "ranking_geral.md")
    FileUtils.mkdir_p(output.dirname)
    File.write(output, LeaderboardMarkdown.new(rows).call)
    puts "#{rows.size} pilotos exportados para #{output}"
  end
end