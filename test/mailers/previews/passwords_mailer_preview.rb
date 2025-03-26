class PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://done.test:3000/rails/mailers/passwords_mailer/reset
  def reset
    PasswordsMailer.reset(User.take)
  end
end
