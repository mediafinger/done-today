ActiveRecordDoctor.configure do
  # Global settings affect all detectors.
  # Ignore internal Rails-related tables.
  global :ignore_tables, %w[
    ar_internal_metadata
    schema_migrations
    active_storage_blobs
    active_storage_attachments
    action_text_rich_texts
    pg_search_documents
    solid_cable_messages
    solid_cache_entries
    solid_queue_blocked_executions
    solid_queue_claimed_executions
    solid_queue_failed_executions
    solid_queue_jobs
    solid_queue_pauses
    solid_queue_processes
    solid_queue_ready_executions
    solid_queue_recurring_executions
    solid_queue_recurring_tasks
    solid_queue_scheduled_executions
    solid_queue_semaphores
  ]

  global :ignore_models, %w[
    ActiveStorage::Attachment
    ActiveStorage::Blob
    ActiveStorage::Record
    ActiveStorage::VariantRecord
    ApplicationRecord
    PgSearch::Document
    SolidCable::Message
    SolidCache::Entry
    SolidQueue::Job
    SolidQueue::BlockedExecution
    SolidQueue::ClaimedExecution
    SolidQueue::FailedExecution
    SolidQueue::Pause
    SolidQueue::Process
    SolidQueue::ReadyExecution
    SolidQueue::RecurringExecution
    SolidQueue::RecurringTask
    SolidQueue::ScheduledExecution
    SolidQueue::Semaphore
  ]

  detector :incorrect_dependent_option, ignore_associations: %w[

  ]

  # app only validation sufficient, no need to enforce length in DB
  detector :incorrect_length_validation, ignore_attributes: %w[

  ]

  detector :missing_foreign_keys, ignore_columns: %w[

  ]

  detector :missing_non_null_constraint, ignore_columns: %w[

  ]

  detector :missing_presence_validation, ignore_attributes: %w[

  ]

  detector :short_primary_key_type, ignore_tables: %w[

  ]

  detector :undefined_table_references, ignore_models: %w[

  ]

  # Ignore indices that are not used in the application
  detector :unindexed_foreign_keys, ignore_columns: %w[

  ]
end
