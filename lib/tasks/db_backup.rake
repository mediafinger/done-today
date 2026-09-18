# Thin wrappers so the backup is discoverable from `rake -T` alongside the other db
#   tasks. The scripts stay the real implementation: they must keep working when the
#   app does not boot, which is exactly when a backup matters most, so nothing here
#   is allowed to become a dependency of taking one.
#
namespace :db do
  desc "Dump the database to $DONE_BACKUP_DIR (default ~/db_backups/done_today)"
  task :backup do
    script = Rails.root.join("script/db_backup.sh")

    abort "missing #{script}" unless File.executable?(script)
    abort "backup failed" unless system(script.to_s)
  end

  namespace :backup do
    desc "Restore the newest dump into a scratch database to prove it loads, then drop it"
    task :verify do
      script = Rails.root.join("script/db_restore.sh")

      abort "missing #{script}" unless File.executable?(script)
      abort "backup verification failed" unless system(script.to_s)
    end

    desc "List the available dumps"
    task :list do
      system(Rails.root.join("script/db_restore.sh").to_s, "--list")
    end
  end
end
