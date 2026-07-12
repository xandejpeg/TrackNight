class ComparisonController < ApplicationController
  def show
    @profiles = DriverProfile.order(:kind, :id).to_a
    @profile_a = @profiles.find { |p| p.code == params[:a].to_s.upcase } || @profiles.first
    @profile_b = @profiles.find { |p| p.code == params[:b].to_s.upcase && p != @profile_a } ||
                 @profiles.find { |p| p != @profile_a }
    return unless @profile_a && @profile_b
    @stats_a = PerformanceStats.new(profile_codes: [ @profile_a.code ])
    @stats_b = PerformanceStats.new(profile_codes: [ @profile_b.code ])
  end
end
