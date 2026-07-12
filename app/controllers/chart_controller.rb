class ChartController < ApplicationController
  def show
    @stats = stats_for_current_profile
    # O gráfico principal sempre traz todas as corridas (ACF + AC),
    # respeitando período/temperatura/clima.
    @evolution = PerformanceStats.new(
      profile_code: "todos",
      period: current_period,
      temp: current_temp,
      weather: current_weather
    ).evolution
    @sessions = @stats.sessions
  end
end
