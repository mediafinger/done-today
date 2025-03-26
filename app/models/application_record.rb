class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def create_with_history(record, history_params = {})
    transaction do
      record.save && RecordHistoryService.call(record:, event: :created, **history_params)
    end
  end

  def update_with_history(record, history_params = {})
    transaction do
      record.save && RecordHistoryService.call(record:, event: :updated, **history_params)
    end
  end

  def destroy_with_history(record, history_params = {})
    transaction do
      RecordHistoryService.call(record:, event: :deleted, **history_params)
      record.destroy! # TODO: refactor controller actions to not raise
    end
  end
end
