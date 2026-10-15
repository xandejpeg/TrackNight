module Admin
  class UsersController < BaseController
    helper_method :user_stats

    def index
      @users = User.order(:username).includes(:drivers, :race_sessions, :source_documents)
    end

    def show
      @user = User.find(params[:id])
      @profiles = @user.driver_profiles
      @sessions = @user.race_sessions.chronological.includes(:result_entries)
      @uploads = @user.source_documents.order(created_at: :desc).limit(10)
      @best_lap_ms = ResultEntry.where(driver_profile: @profiles).filter_map(&:best_lap_ms).min
    end

    private

    def user_stats(user)
      profiles = user.driver_profiles
      entries = ResultEntry.where(driver_profile: profiles)
      {
        profiles: profiles.map(&:code),
        uploads: user.source_documents.size,
        sessions: user.race_sessions.size,
        confirmed: user.race_sessions.confirmed.size,
        best_lap_ms: entries.filter_map(&:best_lap_ms).min
      }
    end
  end
end
