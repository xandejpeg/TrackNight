class TrackController < ApplicationController
  def show
    @venue = Venue.find_by!(slug: "kgv")
    @layout = @venue.track_layouts.find_by!(slug: "circuito-101")
    @sectors = @layout.track_sectors
    @sources = @layout.track_sources
    @stats = stats_for_current_profile
  end
end
