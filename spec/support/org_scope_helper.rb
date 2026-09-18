module OrgScopeHelper
  #
  #
  # Capybara "visit page" methods
  #
  # def visit_switch_current_org(org)
  #   visit "#{base_url}/switch_current_orgs"

  #   page.find(id: org.id).click # "Select this org" button
  # end

  # def visit_go_solo(org)
  #   visit "#{base_url}/switch_current_orgs"

  #   page.find(id: org.id).click # "go solo" button
  # end

  #
  #
  # RSpec / Rails System spec "get response" methods
  #
  # def switch_current_org(org)
  #   post switch_current_orgs_path, params: { current_org: { org_id: org.id } }
  # end

  # def go_solo(org)
  #   delete switch_current_org_path(org)
  # end
end

RSpec.configure do |config|
  config.include OrgScopeHelper, type: :system
end
