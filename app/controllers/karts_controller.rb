class KartsController < ApplicationController
  def index
    @stats = stats_for_current_profile
    @kart_stats = @stats.kart_stats
  end
end
