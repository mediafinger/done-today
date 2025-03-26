# rubocop:disable Rails/Output
Rails.application.console do
  if AppConf.is?(:environment, :development)
    # alias class User to USer (my favority fast-typing typo)
    USer = User

    @andy, @rinse = User.find_by(name: %w[andy rinse])
    @zazu         = Org.find_by(name: "zazu")
    @demo         = Project.find_by(name: "demo app")

    puts "Zazu development console - initialized @andy @rinse @zazu @demo"
    puts "don't forget about `show_cmds`"
  end
end
# rubocop:enable Rails/Output
