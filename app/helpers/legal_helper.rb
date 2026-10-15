module LegalHelper
  # Registered with `required: production_env?` in AppConf
  REQUIRED_KEYS = %i[
    legal_operator_name legal_street legal_city legal_email legal_hosting_provider legal_mail_provider
  ].freeze

  # Required value, or a visible placeholder outside production
  def legal(key)
    legal_optional(key) || tag.mark("#{key.upcase} nicht konfiguriert")
  end

  def legal_optional(key)
    AppConf.public_send(key).presence
  end

  def legal_email_link
    email = legal_optional(:legal_email)
    email ? mail_to(email) : legal(:legal_email)
  end

  def legal_unconfigured_keys
    REQUIRED_KEYS.reject { legal_optional(it) }
  end
end
