class Org < ApplicationRecord
  has_many :days, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :members, inverse_of: :org, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :record_histories, dependent: :destroy

  has_many :users, through: :members

  validates :name, presence: true, uniqueness: true
end
