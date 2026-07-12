class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_login
  before_action :enforce_password_change

  helper_method :current_user, :current_profile_code, :profile_filter_options

  PROFILE_CODES = %w[ACF AC].freeze

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

  def profile_filter_options
    [ [ "Todos os perfis", "todos" ] ] + DriverProfile.order(:kind).map { |p| [ p.display_name, p.code ] }
  end

  def stats_for_current_profile
    PerformanceStats.new(profile_code: current_profile_code)
  end
end
