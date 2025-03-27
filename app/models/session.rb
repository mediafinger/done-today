class Session < ApplicationRecord
  belongs_to :org, optional: true
  belongs_to :user

  before_validation :set_default_org, if: -> { org.blank? }, on: :create

  private

  def set_default_org
    return unless user.present?

    self.org = user.orgs.size == 1 ? user.orgs.first : nil
  end
end
