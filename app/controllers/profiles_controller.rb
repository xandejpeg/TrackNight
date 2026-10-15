class ProfilesController < ApplicationController
  def index
    @profiles = current_user.driver_profiles.order(:id)
    @stats_by_code = @profiles.index_with { |p| PerformanceStats.new(user: current_user, profile_codes: [ p.code ]) }
    @rankings = @profiles.index_with { |p| ProfileRanking.new(p).call }
  end

  def show
    @profile = current_user.driver_profiles.find_by!(code: params[:code])
    @stats = PerformanceStats.new(user: current_user, profile_codes: [ @profile.code ])
    @evolution = @stats.evolution
    @ranking = ProfileRanking.new(@profile).call
  end

  def new
    @profile = DriverProfile.new(color: "#00a8e8")
  end

  def edit
    @profile = current_user.driver_profiles.find_by!(code: params[:code])
  end

  def create
    @profile = DriverProfile.new(profile_params)
    @profile.driver = current_user.drivers.first
    @profile.code = @profile.code.to_s.strip.upcase
    if @profile.save
      redirect_to profiles_path, notice: "Conta #{@profile.code} adicionada."
    else
      flash.now[:alert] = @profile.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @profile = current_user.driver_profiles.find_by!(code: params[:code])
    attributes = profile_params
    attributes[:ranking_override] = nil if attributes[:ranking_override].blank?
    if @profile.update(attributes)
      redirect_to profiles_path, notice: "Configurações da conta #{@profile.code} atualizadas."
    else
      flash.now[:alert] = @profile.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:driver_profile).permit(:code, :display_name, :color, :ranking_override)
  end
end
