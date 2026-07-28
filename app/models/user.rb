class User < ApplicationRecord
  has_secure_password

  enum :role, { member: 0, admin: 1 }

  has_many :drivers, dependent: :destroy
  has_many :race_sessions, dependent: :destroy
  has_many :source_documents, dependent: :destroy
  has_many :import_batches, dependent: :destroy
  has_many :driver_profiles, through: :drivers

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :full_name, :cpf, presence: true, if: :member?
  validates :cpf, uniqueness: true, allow_blank: true
  validates :cpf, cpf: true, allow_blank: true

  normalizes :cpf, with: ->(cpf) { cpf.to_s.gsub(/\D/, "") }

  # Recuperação de senha por identidade (sem email): CPF + nome completo
  def authenticate_identity(cpf, full_name)
    return false unless member?
    normalized_cpf = cpf.to_s.gsub(/\D/, "")
    normalized_name = full_name.to_s.strip.downcase
    self.cpf == normalized_cpf && self.full_name.to_s.strip.downcase == normalized_name
  end

  def generate_password_reset_token
    token = SecureRandom.urlsafe_base64(32)
    update!(password_reset_token: token, password_reset_sent_at: Time.current)
    token
  end

  def self.find_by_password_reset_token(token)
    return nil if token.blank?
    user = find_by(password_reset_token: token)
    user if user&.password_reset_sent_at&.>(2.hours.ago)
  end

  def clear_password_reset_token
    update!(password_reset_token: nil, password_reset_sent_at: nil)
  end

  # Cria o driver e perfil padrão no cadastro: o nome completo vira o alvo do OCR.
  def setup_default_driver!
    return drivers.first if drivers.exists?

    base_slug = full_name.to_s.parameterize.presence || username.to_s.parameterize
    slug = base_slug
    slug = "#{base_slug}-#{SecureRandom.hex(3)}" while Driver.exists?(slug: slug)

    driver = drivers.create!(name: full_name, slug: slug)
    driver.driver_aliases.create!(name: full_name)

    code = username.to_s.upcase.gsub(/[^A-Z0-9]/, "").first(6).presence || "PILOTO"
    code = "#{code}#{rand(10)}" while DriverProfile.exists?(code: code)

    driver.driver_profiles.create!(
      code: code,
      display_name: full_name,
      color: "#e10600"
    )
    driver
  end
end
