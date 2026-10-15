class PasswordResetsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :enforce_password_change
  layout "auth"

  def new
  end

  def create
    user = User.find_by("LOWER(username) = ?", params[:username].to_s.downcase)

    if user&.authenticate_identity(params[:cpf], params[:full_name])
      token = user.generate_password_reset_token
      redirect_to edit_password_reset_path(token: token, username: user.username),
                  notice: "Identidade confirmada. Defina sua nova senha."
    else
      flash.now[:alert] = "Dados não conferem. Verifique usuário, CPF e nome completo."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @user = User.find_by_password_reset_token(params[:token])
    unless @user
      redirect_to new_password_reset_path, alert: "Link inválido ou expirado. Tente novamente."
    end
  end

  def update
    @user = User.find_by_password_reset_token(params[:token])
    return redirect_to new_password_reset_path, alert: "Link inválido ou expirado." unless @user

    if params[:password].to_s.length < 6
      flash.now[:alert] = "A senha precisa de pelo menos 6 caracteres."
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password: params[:password], must_change_password: false)
      @user.clear_password_reset_token
      redirect_to login_path, notice: "Senha redefinida. Faça login com a nova senha."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
