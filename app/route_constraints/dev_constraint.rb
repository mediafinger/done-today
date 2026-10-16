# Routes /dev in development only (config/routes.rb), the settings link it on the same condition.
#   Not in test: development-only routes may need gems or config that tests don't load.
class DevConstraint
  def self.matches?(_request = nil)
    Rails.env.development?
  end
end
