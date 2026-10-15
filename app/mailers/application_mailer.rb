class ApplicationMailer < ActionMailer::Base
  default from: -> { AppConf.default_email_sender }
  layout "mailer"
end
