# Builds the ActionMailer config from AppConf, so production can be specced without booting it.
class MailSettings
  class Invalid < StandardError; end

  # example.com/.net/.org (RFC 2606) and the reserved TLDs never receive mail
  RESERVED_DOMAIN = /(\A|\.)(example\.(com|net|org)|example|test|invalid|localhost)\z/i
  IMPLICIT_TLS_PORT = 465

  def initialize(conf = AppConf)
    @conf = conf
  end

  def apply(action_mailer)
    validate!

    action_mailer.delivery_method = delivery_method
    action_mailer.smtp_settings = smtp_settings
    action_mailer.default_url_options = default_url_options
  end

  def delivery_method = conf.mail_delivery_method.to_sym

  def default_url_options = { host: conf.done_host, protocol: "https" }

  def smtp_settings
    port = conf.smtp_port.to_i
    tls = port == IMPLICIT_TLS_PORT ? { tls: true, enable_starttls_auto: false } : { enable_starttls: true }

    {
      address: conf.smtp_address,
      port:,
      domain: conf.smtp_domain,
      user_name: conf.smtp_username,
      password: conf.smtp_password,
      authentication: conf.smtp_authentication.to_sym,
      **tls
    }
  end

  def validate!
    return unless conf.production_env?

    errors = []
    errors << "MAIL_DELIVERY_METHOD must be smtp, got #{delivery_method}" unless delivery_method == :smtp
    errors << "DEFAULT_EMAIL_SENDER uses a reserved domain" if reserved?(conf.default_email_sender.to_s[/@([^>\s]+)/, 1])
    errors << "DONE_HOST is a reserved domain" if reserved?(conf.done_host)

    raise Invalid, errors.join(", ") if errors.any?
  end

  private

  attr_reader :conf

  def reserved?(domain) = domain.to_s.empty? || domain.match?(RESERVED_DOMAIN)
end
