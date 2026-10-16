# Routes /dev in development and test only (config/routes.rb), the settings link it on the same condition.
class DevConstraint
  def self.matches?(_request = nil)
    Rails.env.local?
  end
end
