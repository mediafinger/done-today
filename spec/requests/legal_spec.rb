require "rails_helper"

RSpec.describe "Legal pages" do
  let(:operator) do
    {
      legal_operator_name: "Erika Mustermann",
      legal_street: "Musterstraße 1",
      legal_city: "12345 Musterstadt",
      legal_email: "kontakt@example.org",
      legal_hosting_provider: "Example Hosting GmbH",
      legal_mail_provider: "Example Mail GmbH"
    }
  end

  def configure(values)
    values.each { |key, value| allow(AppConf).to receive(key).and_return(value) }
  end

  describe "GET /impressum" do
    it "is public" do
      get imprint_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Impressum")
    end

    it "renders the configured operator details" do
      configure(operator)

      get imprint_path

      expect(response.body).to include("Erika Mustermann", "Musterstraße 1", "12345 Musterstadt", "kontakt@example.org")
      expect(response.body).not_to include("nicht konfiguriert")
    end

    it "marks missing required details as not configured" do
      configure(operator.merge(legal_operator_name: nil, legal_email: ""))

      get imprint_path

      expect(response.body).to include("LEGAL_OPERATOR_NAME nicht konfiguriert", "LEGAL_EMAIL nicht konfiguriert")
    end

    it "omits optional details that are not set" do
      configure(operator.merge(legal_phone: nil, legal_vat_id: nil, legal_register: nil, legal_representative: nil))

      get imprint_path

      expect(response.body).not_to include("Telefon", "Umsatzsteuer", "Registereintrag", "Vertreten durch")
    end

    it "shows optional details when set" do
      configure(operator.merge(legal_phone: "+49 30 1234567", legal_vat_id: "DE999999999",
        legal_register: "Amtsgericht Musterstadt, HRB 1", legal_representative: "Max Mustermann"))

      get imprint_path

      expect(response.body).to include("+49 30 1234567", "DE999999999", "Amtsgericht Musterstadt, HRB 1", "Max Mustermann")
    end
  end

  describe "GET /datenschutz" do
    it "is public" do
      get privacy_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Datenschutzerklärung")
    end

    it "is marked as a draft pending legal review" do
      get privacy_path

      expect(response.body).to include("Entwurf")
    end

    it "names the controller and the configured processors" do
      configure(operator)

      get privacy_path

      expect(response.body).to include("Erika Mustermann", "Example Hosting GmbH", "Example Mail GmbH")
      expect(response.body).not_to include("nicht konfiguriert")
    end

    it "lists the cookies the app sets" do
      get privacy_path

      expect(response.body).to include("session_id", "_done_today_session", "display_mode")
    end
  end

  describe "links" do
    it "are on the login page" do
      get new_session_path

      expect(response.body).to include(%(href="#{imprint_path}"), %(href="#{privacy_path}"))
    end

    it "are in the footer for signed-in users" do
      sign_in(create(:user))
      follow_redirect!

      expect(response.body).to include(%(href="#{imprint_path}"), %(href="#{privacy_path}"))
    end
  end

  it "renders for signed-in users too" do
    sign_in(create(:user))

    get privacy_path

    expect(response).to have_http_status(:ok)
  end
end
