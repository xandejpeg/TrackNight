class RankingController < ApplicationController
  def index
    @profiles = DriverProfile.order(:kind, :id).to_a
    @rankings = @profiles.index_with { |profile| ProfileRanking.new(profile).call }
    @leaderboard = filtered_leaderboard
    @owned_row = leaderboard.find(&:owned)
  end

  def export
    markdown = LeaderboardMarkdown.new(leaderboard).call
    send_data markdown,
      filename: "ranking-geral-#{Date.current.iso8601}.md",
      type: "text/markdown; charset=utf-8",
      disposition: "attachment"
  end

  private

  def leaderboard
    @leaderboard_all ||= GlobalLeaderboard.new.call
  end

  def filtered_leaderboard
    query = ParticipantName.normalize(params[:q])
    return leaderboard if query.empty?

    leaderboard.select do |row|
      row.normalized_name.include?(query) || row.aliases.any? { |name| ParticipantName.normalize(name).include?(query) }
    end
  end
end