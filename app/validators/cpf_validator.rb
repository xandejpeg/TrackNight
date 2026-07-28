# Validação de CPF com dígitos verificadores (algoritmo oficial Receita Federal).
class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_blank]
    unless value.match?(/\A\d{11}\z/)
      record.errors.add(attribute, "deve ter 11 dígitos (somente números)")
      return
    end
    unless valid_checksum?(value)
      record.errors.add(attribute, "não é um CPF válido")
    end
  end

  private

  def valid_checksum?(cpf)
    return false if cpf.chars.uniq.size == 1 # rejeita sequências como 111.111.111-11

    digits = cpf.chars.map(&:to_i)

    # Primeiro dígito verificador
    sum = digits[0..8].each_with_index.sum { |d, i| d * (10 - i) }
    check1 = (sum * 10) % 11
    check1 = 0 if check1 == 10
    return false unless digits[9] == check1

    # Segundo dígito verificador
    sum = digits[0..9].each_with_index.sum { |d, i| d * (11 - i) }
    check2 = (sum * 10) % 11
    check2 = 0 if check2 == 10
    digits[10] == check2
  end
end
