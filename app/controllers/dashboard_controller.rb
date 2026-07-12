class DashboardController < ApplicationController
  def show
    @stats = stats_for_current_profile
    @recent_sessions = @stats.sessions.last(5).reverse
    @pending_reviews = SourceDocument.awaiting_review.count
    # O gráfico mostra TODAS as corridas (perfis ACF e AC), respeitando os demais filtros.
    @evolution = PerformanceStats.new(
      profile_code: "todos",
      period: current_period,
      temp: current_temp,
      weather: current_weather
    ).evolution
  end
end
