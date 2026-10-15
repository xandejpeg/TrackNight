class OnboardingController < ApplicationController
  layout "onboarding"

  STEPS = %w[modalidade tipo pistas tour].freeze

  def show
    @step = params[:step].presence_in(STEPS) || STEPS.first
    redirect_to dashboard_path if current_user.onboarding_completed? && @step != "tour"
  end

  def update
    case params[:step]
    when "modalidade"
      current_user.update!(vehicle_preference: params[:vehicle_preference])
      redirect_to onboarding_step_path("tipo")
    when "tipo"
      current_user.update!(racing_type: params[:racing_type])
      redirect_to onboarding_step_path("pistas")
    when "pistas"
      sync_track_layouts(Array(params[:track_layout_ids]))
      redirect_to onboarding_step_path("tour")
    else
      redirect_to dashboard_path
    end
  end

  def complete
    current_user.complete_onboarding!
    redirect_to new_import_path, notice: "◆ Bandeirada — Perfil configurado. Agora importe sua primeira folha de tempos."
  end

  private

  def sync_track_layouts(ids)
    layout_ids = TrackLayout.where(id: ids, active: true).pluck(:id)
    current_user.user_track_layouts.where.not(track_layout_id: layout_ids).destroy_all
    layout_ids.each do |lid|
      current_user.user_track_layouts.find_or_create_by!(track_layout_id: lid)
    end
  end
end
