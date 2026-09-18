# `User` validates its password against the Have I Been Pwned API (`not_pwned`).
# Every `create(:user)` would otherwise make a real HTTPS call to api.pwnedpasswords.com,
# which makes the suite slow, flaky and unusable offline.
#
# Prepending is preferred over `allow_any_instance_of` here: it costs nothing per example
# and keeps the stub out of the individual specs.
#
# To exercise the validator itself, stub `pwned_count` explicitly in that example.
#
require "pwned"

module PwnedStub
  def pwned_count = 0
end

Pwned::Password.prepend(PwnedStub)
