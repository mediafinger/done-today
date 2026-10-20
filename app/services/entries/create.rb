module Entries
  # A new entry on the day of `date`, which is created along with it.
  #
  #   Entries::Create.call(project:, member:, date:, log:) # => #<data Entries::Result entry=#<Entry …>, saved=true>
  #
  class Create
    def self.call(project:, member:, date:, log:, status: nil, unlocked: false)
      day = project.days.find_or_initialize_by(org: project.org, date:)
      entry = Entry.new(org: project.org, member:, day:, log:, status: status || "todo")

      # a failing history takes the new day along
      saved = Entries.open_day?(entry, unlocked:) &&
        Entry.transaction { day.save! && entry.create_with_history }

      Result.new(entry:, saved:)
    end
  end
end
