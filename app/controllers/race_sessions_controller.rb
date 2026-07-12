class RaceSessionsController < ApplicationController
  def index
    @stats = stats_for_current_profile
    @sessions = @stats.sessions.reverse
  end

  def show
    @session = RaceSession.includes(result_entries: :kart).find(params[:id])
    @entry = @session.alessandro_entry
    stats = PerformanceStats.new(profile_code: @session.driver_profile&.code || "todos")
    @record_fields = @entry ? stats.record_breaking_fields(@entry) : []
    @session_bests = {
      best_lap_ms: @session.session_best(:best_lap_ms),
      s1_ms: @session.session_best(:s1_ms),
      s2_ms: @session.session_best(:s2_ms),
      s3_ms: @session.session_best(:s3_ms),
      speed: @session.session_best_speed
    }
  end

  # Atualiza as condições (temperatura/clima) informadas pelo piloto.
  def update
    session = RaceSession.find(params[:id])
    session.update!(
      track_temp: RaceSession.track_temps.key?(params[:track_temp]) ? params[:track_temp] : nil,
      weather_condition: RaceSession.weather_conditions.key?(params[:weather_condition]) ? params[:weather_condition] : nil
    )
    redirect_to race_session_path(session), notice: "Condições da sessão atualizadas."
  end
end
