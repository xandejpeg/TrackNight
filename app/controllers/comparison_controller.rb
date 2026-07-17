class ComparisonController < ApplicationController
  def show
    @profiles = DriverProfile.order(:kind, :id).to_a
    @profile_a = @profiles.find { |p| p.code == params[:a].to_s.upcase } || @profiles.first
    @profile_b = @profiles.find { |p| p.code == params[:b].to_s.upcase && p != @profile_a } ||
                 @profiles.find { |p| p != @profile_a }
    return unless @profile_a && @profile_b
    @stats_a = PerformanceStats.new(profile_codes: [ @profile_a.code ])
    @stats_b = PerformanceStats.new(profile_codes: [ @profile_b.code ])
    @ranking_a = ProfileRanking.new(@profile_a).call
    @ranking_b = ProfileRanking.new(@profile_b).call
    @ranking_history = [
      *@ranking_a.history.map { |item| [ item, @profile_a ] },
      *@ranking_b.history.map { |item| [ item, @profile_b ] }
    ].sort_by { |item, _profile| [ item.date || Time.at(0), item.race_id ] }.reverse
  end
end
