class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # The history is written from Current.org / Current.user, so these are only usable
  #   inside a request. Pass `org:` / `user:` explicitly from jobs and the console,
  #   and `done_by_admin: true` when an admin fixes data there.
  #
  def create_with_history(**history_params)
    save_with_history(:created, **history_params)
  end

  def update_with_history(**history_params)
    save_with_history(:updated, **history_params)
  end

  def destroy_with_history(**history_params)
    transaction do
      RecordHistoryService.call(record: self, event: :deleted, **history_params)
      destroy
    end
  end

  private

  # A failing history rolls the save back. A save without changes is no edit.
  def save_with_history(event, **history_params)
    transaction do
      next false unless save
      next true if event == :updated && previous_changes.empty?

      RecordHistoryService.call(record: self, event:, **history_params)
      true
    end
  end
end
