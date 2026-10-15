module Admin
  class DashboardController < BaseController
    def index
      @users_count = User.count
      @members_count = User.member.count
      @sessions_count = RaceSession.count
      @confirmed_sessions_count = RaceSession.confirmed.count
      @documents_count = SourceDocument.count
      @pending_reviews = SourceDocument.where(status: "parsed").count
      @recent_users = User.order(created_at: :desc).limit(5)
      @recent_imports = SourceDocument.order(created_at: :desc).limit(5)
    end
  end
end
