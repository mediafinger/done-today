class ProjectIntegration < ApplicationRecord
  belongs_to :org
  belongs_to :project
  belongs_to :integration

  before_validation :set_org

  private

  def set_org
    self.org ||= project.org
  end
end
