class Integration < ApplicationRecord
  VALID_SERVICES = %w[email slack].freeze
  VALID_TYPES = %w[reminder notification summary].freeze

  belongs_to :org

  has_many :project_integrations, dependent: :destroy
  has_many :projects, through: :project_integrations

  validates :credentials, presence: true # it's a JSONB column, maybe add better validation
  validates :integration_type, presence: true, inclusion: { in: VALID_TYPES }
  validates :service, presence: true, inclusion: { in: VALID_SERVICES }
  validates :template, presence: true
end
