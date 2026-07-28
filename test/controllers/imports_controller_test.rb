require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "delete-test-user", password: "123321",
                         full_name: "Usuário de Teste", cpf: "52998224725")
    post login_path, params: { username: @user.username, password: "123321" }
  end

  test "deletes a parsed session awaiting review" do
    document = source_document(status: "parsed")

    assert_difference("SourceDocument.count", -1) do
      delete import_path(document)
    end

    assert_redirected_to imports_path
    assert_equal "Sessão pendente pending-test.png apagada.", flash[:notice]
  end

  test "does not delete an imported session" do
    document = source_document(status: "imported")

    assert_no_difference("SourceDocument.count") do
      delete import_path(document)
    end

    assert_redirected_to imports_path
    assert_equal "Sessões já importadas não podem ser apagadas por aqui.", flash[:alert]
    assert SourceDocument.exists?(document.id)
  end

  test "deletes a document stuck in the OCR queue" do
    document = source_document(status: "pending")

    assert_difference("SourceDocument.count", -1) do
      delete import_path(document)
    end

    assert_redirected_to imports_path
  end

  private

  def source_document(status:)
    SourceDocument.create!(
      filename: "pending-test.png",
      sha256: SecureRandom.hex(32),
      status: status,
      user: @user,
      parsed_data: { rows: [] }
    )
  end
end
