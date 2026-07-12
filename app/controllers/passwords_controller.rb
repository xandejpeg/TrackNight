class PasswordsController < ApplicationController
  skip_before_action :enforce_password_change

  def edit
  end

  def update
    unless current_user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "Senha atual incorreta."
      return render :edit, status: :unprocessable_entity
    end
    if params[:password].to_s.length < 6
      flash.now[:alert] = "A nova senha precisa de pelo menos 6 caracteres."
      return render :edit, status: :unprocessable_entity
    end
    if current_user.update(password: params[:password], must_change_password: false)
      redirect_to root_path, notice: "Senha atualizada."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
