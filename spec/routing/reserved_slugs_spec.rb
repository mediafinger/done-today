require "rails_helper"

# Org and project slugs share the path with the app's own pages: /settings vs /acme,
#   /acme/members vs /acme/website. Every literal path segment has to be reserved.
RSpec.describe "Reserved slugs" do
  let(:paths) { Rails.application.routes.routes.map { |route| route.path.spec.to_s.delete_suffix("(.:format)") } }

  def literal?(segment)
    segment.present? && !segment.start_with?(":", "*", "(")
  end

  it "reserves every top-level path for orgs" do
    segments = paths.filter_map { |path| path.split("/")[1] }.select { literal?(it) }.uniq

    expect(segments - Org::RESERVED_SLUGS).to be_empty
  end

  it "reserves every file in public/ for orgs" do
    names = Rails.public_path.children.map { it.basename.to_s.sub(/\..*\z/, "") }

    expect(names - Org::RESERVED_SLUGS).to be_empty
  end

  it "reserves every org-level path for projects" do
    segments = paths.filter_map { |path| path.split("/")[2] if path.start_with?("/:org_slug/") }.select { literal?(it) }.uniq

    expect(segments - Project::RESERVED_SLUGS).to be_empty
  end
end
