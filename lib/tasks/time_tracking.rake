namespace :time_tracking do
  desc "Re-parse every entry log, so the time-tracking columns match the current grammar"
  task backfill: :environment do
    # `log` is the source of truth and the columns are only its projection, so the
    # way to rebuild them is to run the text through the parser again. Whenever the
    # grammar learns a new token, this task brings existing entries up to date --
    # today it is close to a no-op, because no entry was written with markup yet.
    #
    total = Entry.count
    changed = 0
    failed = []

    puts "Re-parsing #{total} #{'entry'.pluralize(total)}..."

    Entry.find_each do |entry|
      entry.log_will_change! # the text is unchanged, so only the parse callback has to run

      if entry.save(touch: false) # `updated_at` would lie: nothing the user wrote has changed
        changed += 1 if entry.previous_changes.keys.intersect?(Entry::PARSED_COLUMNS)
      else
        failed << [ entry.id, entry.errors.full_messages.to_sentence ]
      end
    end

    puts "Updated #{changed} of #{total}."
    next if failed.empty?

    puts "#{failed.size} could not be saved:"
    failed.each { |id, errors| puts "  #{id}: #{errors}" }
    abort "Backfill incomplete"
  end
end
