class Project < ApplicationRecord
  belongs_to :org

  has_many :days, dependent: :destroy
  has_many :participants, inverse_of: :project, dependent: :destroy
  has_many :project_integrations, dependent: :destroy

  has_many :entries, through: :days
  has_many :integrations, through: :project_integrations
  has_many :members, through: :participants

  validates :name, presence: true, uniqueness: { scope: :org_id }
end
