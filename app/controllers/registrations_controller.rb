class RegistrationsController < ApplicationController
  skip_before_action :require_login
  layout "auth"

  def new
    redirect_to root_path if current_user
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      @user.setup_default_driver!
      reset_session
      session[:user_id] = @user.id
      redirect_to onboarding_step_path("modalidade"), notice: "◆ Bandeirada — Conta criada. Vamos configurar seu perfil."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:full_name, :username, :cpf, :password, :password_confirmation)
  end
end
