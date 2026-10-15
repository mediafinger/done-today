require "rails_helper"

RSpec.describe MailSettings do
  subject(:settings) { described_class.new(conf) }

  let(:conf) { class_double(AppConf, **production_conf) }
  let(:production_conf) do
    {
      production_env?: true,
      done_host: "done.mediafinger.eu",
      mail_delivery_method: "smtp",
      default_email_sender: "Done <noreply@mediafinger.eu>",
      smtp_address: "smtp.mail.eu",
      smtp_port: "587",
      smtp_domain: "done.mediafinger.eu",
      smtp_username: "done",
      smtp_password: "s3cret",
      smtp_authentication: "plain"
    }
  end

  describe "#default_url_options" do
    it "builds https links to the configured host" do
      expect(settings.default_url_options).to eq(host: "done.mediafinger.eu", protocol: "https")
    end
  end

  describe "#delivery_method" do
    it "reads MAIL_DELIVERY_METHOD" do
      expect(settings.delivery_method).to eq(:smtp)
    end
  end

  describe "#smtp_settings" do
    it "maps the SMTP keys and enforces STARTTLS on the submission port" do
      expect(settings.smtp_settings).to eq(
        address: "smtp.mail.eu",
        port: 587,
        domain: "done.mediafinger.eu",
        user_name: "done",
        password: "s3cret",
        authentication: :plain,
        enable_starttls: true
      )
    end

    it "uses implicit TLS on port 465" do
      production_conf[:smtp_port] = "465"

      expect(settings.smtp_settings).to include(port: 465, tls: true, enable_starttls_auto: false)
      expect(settings.smtp_settings).not_to have_key(:enable_starttls)
    end
  end

  describe "#apply" do
    let(:action_mailer) { ActiveSupport::OrderedOptions.new }

    it "configures delivery, SMTP and link host" do
      settings.apply(action_mailer)

      expect(action_mailer.delivery_method).to eq(:smtp)
      expect(action_mailer.smtp_settings).to eq(settings.smtp_settings)
      expect(action_mailer.default_url_options).to eq(host: "done.mediafinger.eu", protocol: "https")
    end

    it "refuses a delivery method other than smtp in production" do
      production_conf[:mail_delivery_method] = "letter_opener"

      expect { settings.apply(action_mailer) }.to raise_error(MailSettings::Invalid, /MAIL_DELIVERY_METHOD/)
    end

    [ "from@example.com", "Done <done@mail.example.org>", "done@done.test" ].each do |sender|
      it "refuses the placeholder sender #{sender} in production" do
        production_conf[:default_email_sender] = sender

        expect { settings.apply(action_mailer) }.to raise_error(MailSettings::Invalid, /DEFAULT_EMAIL_SENDER/)
      end
    end

    it "refuses a placeholder host in production" do
      production_conf[:done_host] = "done.test"

      expect { settings.apply(action_mailer) }.to raise_error(MailSettings::Invalid, /DONE_HOST/)
    end

    it "accepts placeholders outside production" do
      production_conf.merge!(production_env?: false, default_email_sender: "from@example.com", done_host: "done.test")

      expect { settings.apply(action_mailer) }.not_to raise_error
    end
  end
end
