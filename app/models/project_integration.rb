class ProjectIntegration < ApplicationRecord
  belongs_to :org
  belongs_to :project
  belongs_to :integration
end
