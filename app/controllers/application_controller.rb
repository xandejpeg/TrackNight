class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_login
  before_action :enforce_password_change

  helper_method :current_user, :current_profiles, :profiles_filtered?,
                :current_period, :current_temp, :current_weather, :active_filters_count

  PROFILE_CODES = %w[ACF AC].freeze
  PERIODS = %w[dia noite].freeze

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def require_login
    redirect_to login_path unless current_user
  end

  def enforce_password_change
    return unless current_user&.must_change_password
    redirect_to edit_password_path unless controller_name.in?(%w[passwords sessions])
  end

  # Filtro de perfil compartilhado: toggles multi-seleção (?profiles=ACF,AC).
  # Nenhum ou todos selecionados = todas as corridas.
  def current_profiles
    @current_profiles ||= begin
      codes = params[:profiles].to_s.split(",").map { |c| c.strip.upcase }.uniq & PROFILE_CODES
      # Compatibilidade com links antigos ?profile=ACF
      if codes.empty?
        legacy = params[:profile].to_s.upcase
        codes = [ legacy ] if PROFILE_CODES.include?(legacy)
      end
      codes.empty? || codes.sort == PROFILE_CODES.sort ? PROFILE_CODES.dup : codes
    end
  end

  def profiles_filtered?
    current_profiles.sort != PROFILE_CODES.sort
  end

  def current_period
    PERIODS.include?(params[:period]) ? params[:period] : nil
  end

  def current_temp
    RaceSession.track_temps.key?(params[:temp]) ? params[:temp] : nil
  end

  def current_weather
    RaceSession.weather_conditions.key?(params[:weather]) ? params[:weather] : nil
  end

  def active_filters_count
    [ profiles_filtered?, current_period, current_temp, current_weather ].count(&:present?)
  end

  def stats_for_current_profile
    PerformanceStats.new(
      profile_codes: profiles_filtered? ? current_profiles : nil,
      period: current_period,
      temp: current_temp,
      weather: current_weather
    )
  end
end
