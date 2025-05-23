class Session < ApplicationRecord
  belongs_to :org, optional: true
  belongs_to :project, optional: true
  belongs_to :user
end
