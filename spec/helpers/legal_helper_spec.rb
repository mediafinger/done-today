require "rails_helper"

RSpec.describe LegalHelper do
  def configure(**values)
    LegalHelper::REQUIRED_KEYS.each { allow(AppConf).to receive(it).and_return(values[it]) }
  end

  describe "#legal" do
    it "is the configured value" do
      configure(legal_city: "10115 Berlin")

      expect(helper.legal(:legal_city)).to eq("10115 Berlin")
    end

    it "marks a value that is missing or blank" do
      configure(legal_city: " ")

      expect(helper.legal(:legal_city)).to eq("<mark>LEGAL_CITY nicht konfiguriert</mark>")
    end
  end

  describe "#legal_email_link" do
    it "links the email, or marks it missing" do
      configure(legal_email: "hallo@example.com")
      expect(helper.legal_email_link).to eq(%(<a href="mailto:hallo@example.com">hallo@example.com</a>))

      configure
      expect(helper.legal_email_link).to include("LEGAL_EMAIL nicht konfiguriert")
    end
  end

  describe "#legal_unconfigured_keys" do
    it "lists the required keys without a value" do
      configure(legal_operator_name: "Ada", legal_street: "Weg 1", legal_city: "Berlin", legal_email: "a@example.com")

      expect(helper.legal_unconfigured_keys).to eq(%i[legal_hosting_provider legal_mail_provider])
    end
  end
end
