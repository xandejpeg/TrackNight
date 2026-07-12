class DashboardController < ApplicationController
  def show
    @stats = stats_for_current_profile
    @recent_sessions = @stats.sessions.last(5).reverse
    @pending_reviews = SourceDocument.awaiting_review.count
    # O gráfico respeita todos os filtros da barra, inclusive os toggles de perfil.
    @evolution = @stats.evolution
  end
end
