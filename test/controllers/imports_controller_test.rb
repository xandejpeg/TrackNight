require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(username: "delete-test-user", password: "123321")
    post login_path, params: { username: user.username, password: "123321" }
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
    assert_equal "Somente sessões pendentes podem ser apagadas.", flash[:alert]
    assert SourceDocument.exists?(document.id)
  end

  private

  def source_document(status:)
    SourceDocument.create!(
      filename: "pending-test.png",
      sha256: SecureRandom.hex(32),
      status: status,
      parsed_data: { rows: [] }
    )
  end
end
