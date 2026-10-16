class PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://done.test:3333/rails/mailers/passwords_mailer/reset
  def reset
    Users::PasswordsMailer.reset(User.take)
  end
end
