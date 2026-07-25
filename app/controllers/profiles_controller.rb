class ProfilesController < ApplicationController
  def index
    @profiles = DriverProfile.order(:kind, :id)
    @stats_by_code = @profiles.index_with { |p| PerformanceStats.new(profile_codes: [ p.code ]) }
    @rankings = @profiles.index_with { |p| ProfileRanking.new(p).call }
  end

  def show
    @profile = DriverProfile.find_by!(code: params[:code])
    @stats = PerformanceStats.new(profile_codes: [ @profile.code ])
    @evolution = @stats.evolution
    @ranking = ProfileRanking.new(@profile).call
  end

  def new
    @profile = DriverProfile.new(color: "#00a8e8", kind: :smurf)
  end

  def edit
    @profile = DriverProfile.find_by!(code: params[:code])
  end

  def create
    @profile = DriverProfile.new(profile_params)
    @profile.driver = Driver.first
    @profile.code = @profile.code.to_s.strip.upcase
    if @profile.save
      redirect_to profiles_path, notice: "Conta #{@profile.code} adicionada."
    else
      flash.now[:alert] = @profile.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @profile = DriverProfile.find_by!(code: params[:code])
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
    params.require(:driver_profile).permit(:code, :display_name, :color, :kind, :ranking_override)
  end
end
