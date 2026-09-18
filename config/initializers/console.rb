# rubocop:disable Rails/Output
Rails.application.console do
  if AppConf.is?(:environment, :development)
    # alias class User to USer (my favority fast-typing typo)
    USer = User

    @andy = User.find_by(name: "andy")
    @lyvo = Org.find_by(name: "Lyvo")
    @demo = Project.find_by(name: "2026 V1")

    puts "Done today development console - initialized @andy @lyvo @demo"
    puts "don't forget about `show_cmds`"
  end
end
# rubocop:enable Rails/Output
