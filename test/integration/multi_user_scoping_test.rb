require "test_helper"

class MultiUserScopingTest < ActionDispatch::IntegrationTest
  setup do
    @user_a = User.create!(username: "piloto-a", password: "senha123", full_name: "Piloto A", cpf: "52998224725", onboarding_completed_at: Time.current)
    @user_b = User.create!(username: "piloto-b", password: "senha123", full_name: "Piloto B", cpf: "11144477735", onboarding_completed_at: Time.current)

    @driver_a = @user_a.drivers.create!(name: "Piloto A", slug: "piloto-a")
    @profile_a = @driver_a.driver_profiles.create!(code: "PA", display_name: "Piloto A")

    @driver_b = @user_b.drivers.create!(name: "Piloto B", slug: "piloto-b")
    @profile_b = @driver_b.driver_profiles.create!(code: "PB", display_name: "Piloto B")

    @venue = Venue.find_or_create_by!(slug: "kgv") { |v| v.name = "KGV" }
    @layout = @venue.track_layouts.find_or_create_by!(slug: "circuito-101") { |l| l.name = "Circuito 101" }
    @category = VehicleCategory.find_or_create_by!(slug: "kart-rental") { |c| c.name = "Kart Rental"; c.vehicle_kind = :kart }

    @session_a = RaceSession.create!(
      user: @user_a, venue: @venue, track_layout: @layout, vehicle_category: @category,
      driver_profile: @profile_a, session_type: :prova, review_status: :confirmada
    )
    @session_b = RaceSession.create!(
      user: @user_b, venue: @venue, track_layout: @layout, vehicle_category: @category,
      driver_profile: @profile_b, session_type: :prova, review_status: :confirmada
    )

    @doc_a = SourceDocument.create!(user: @user_a, filename: "a.png", sha256: SecureRandom.hex(32), status: "parsed", parsed_data: { rows: [] })
    @doc_b = SourceDocument.create!(user: @user_b, filename: "b.png", sha256: SecureRandom.hex(32), status: "parsed", parsed_data: { rows: [] })
  end

  test "user A cannot see user B sessions in index" do
    login_as(@user_a)
    get race_sessions_path
    assert_response :success
    # A tabela deve ter exatamente 1 linha de sessão (a do user A)
    assert_select "tbody tr", 1
  end

  test "user A cannot access user B session directly" do
    login_as(@user_a)
    get race_session_path(@session_b)
    assert_response :not_found
  end

  test "user A cannot see user B profile in list" do
    login_as(@user_a)
    get profiles_path
    assert_response :success
    assert_select "p", text: @profile_b.display_name, count: 0
  end

  test "user A cannot access user B profile directly" do
    login_as(@user_a)
    get profile_path(@profile_b.code)
    assert_response :not_found
  end

  test "user A cannot see user B documents in imports" do
    login_as(@user_a)
    get imports_path
    assert_response :success
    assert_no_match @doc_b.filename, response.body
  end

  test "user A cannot access user B document review" do
    login_as(@user_a)
    get review_import_path(@doc_b)
    assert_response :not_found
  end

  test "dashboard shows only own sessions" do
    login_as(@user_a)
    get dashboard_path
    assert_response :success
    # User A has 1 session, user B has 1 session; dashboard should show count 1
    assert_select "p.stat-value", text: "1"
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "senha123" }
  end
end
