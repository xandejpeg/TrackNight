class ChartController < ApplicationController
  def show
    @stats = stats_for_current_profile
    # Gráfico, cards e tabela "Corrida a corrida" respeitam TODOS os
    # filtros da barra: perfil, período, temperatura e clima.
    @evolution = @stats.evolution
    @sessions = @stats.sessions
  end
end
