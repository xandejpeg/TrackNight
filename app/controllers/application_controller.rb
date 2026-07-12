class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_login
  before_action :enforce_password_change

  helper_method :current_user, :current_profile_code, :profile_filter_options,
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

  # Filtro de perfil compartilhado (default: "Todos os perfis")
  def current_profile_code
    code = params[:profile].to_s.upcase
    PROFILE_CODES.include?(code) ? code : "todos"
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
    [ current_profile_code != "todos", current_period, current_temp, current_weather ].count(&:present?)
  end

  def profile_filter_options
    [ [ "Todos os perfis", "todos" ] ] + DriverProfile.order(:kind).map { |p| [ p.display_name, p.code ] }
  end

  def stats_for_current_profile
    PerformanceStats.new(
      profile_code: current_profile_code,
      period: current_period,
      temp: current_temp,
      weather: current_weather
    )
  end
end
