require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "included modules" do
    it "includes Authentication" do
      expect(helper.class.included_modules).to include(Authentication)
    end

    it "includes OrgScope" do
      expect(helper.class.included_modules).to include(OrgScope)
    end

    it "includes ProjectScope" do
      expect(helper.class.included_modules).to include(ProjectScope)
    end
  end

  describe "context dependencies (BUG #21)" do
    it "fails to resolve current_user when request context is missing" do
      pending "Fix Bug #21: ApplicationHelper should not include controller concerns directly as it lacks request context"
      expect { helper.current_user }.not_to raise_error
    end
  end
end
