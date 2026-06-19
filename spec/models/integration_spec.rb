require "rails_helper"

RSpec.describe Integration do
  describe "associations" do
    it "has expected associations" do
      org_assoc = described_class.reflect_on_association(:org)
      expect(org_assoc.macro).to eq(:belongs_to)

      pi_assoc = described_class.reflect_on_association(:project_integrations)
      expect(pi_assoc.macro).to eq(:has_many)
      expect(pi_assoc.options[:dependent]).to eq(:destroy)

      projects_assoc = described_class.reflect_on_association(:projects)
      expect(projects_assoc.macro).to eq(:has_many)
      expect(projects_assoc.options[:through]).to eq(:project_integrations)
    end
  end

  describe "validations" do
    it "validates presence of credentials" do
      integration = build(:integration, credentials: nil)
      expect(integration).not_to be_valid
      expect(integration.errors[:credentials]).to be_present
    end

    it "validates presence and inclusion of integration_type" do
      integration_nil = build(:integration, integration_type: nil)
      expect(integration_nil).not_to be_valid
      expect(integration_nil.errors[:integration_type]).to be_present

      integration_invalid = build(:integration, integration_type: "invalid")
      expect(integration_invalid).not_to be_valid
      expect(integration_invalid.errors[:integration_type]).to be_present
    end

    it "validates presence and inclusion of service" do
      integration_nil = build(:integration, service: nil)
      expect(integration_nil).not_to be_valid
      expect(integration_nil.errors[:service]).to be_present

      integration_invalid = build(:integration, service: "invalid")
      expect(integration_invalid).not_to be_valid
      expect(integration_invalid.errors[:service]).to be_present
    end

    it "validates presence of template" do
      integration = build(:integration, template: nil)
      expect(integration).not_to be_valid
      expect(integration.errors[:template]).to be_present
    end
  end
end
