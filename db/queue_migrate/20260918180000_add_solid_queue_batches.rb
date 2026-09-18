# solid_queue 1.7 added job batches, backed by two new tables. Without them
#   SolidQueue::Batch and SolidQueue::BatchExecution point at tables that do not
#   exist, which is what active_record_doctor's undefined_table_references detector
#   reports after the gem is updated.
#
# Copied from the gem's own db/queue_schema.rb so the two stay in step.
#
class AddSolidQueueBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_queue_batches do |t|
      t.string :active_job_batch_id
      t.string :description
      t.text :on_finish
      t.text :on_success
      t.text :on_failure
      t.text :metadata
      t.integer :total_jobs, default: 0, null: false
      t.integer :completed_jobs, default: 0, null: false
      t.integer :failed_jobs, default: 0, null: false
      t.datetime :enqueued_at
      t.datetime :finished_at
      t.datetime :failed_at
      t.timestamps

      t.index [ :active_job_batch_id ], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
      t.index [ :finished_at ], name: "index_solid_queue_batches_on_finished_at"
    end

    create_table :solid_queue_batch_executions do |t|
      t.bigint :job_id, null: false
      t.bigint :batch_id, null: false
      t.datetime :created_at, null: false

      t.index [ :job_id ], name: "index_solid_queue_batch_executions_on_job_id", unique: true
      t.index [ :batch_id ], name: "index_solid_queue_batch_executions_on_batch_id"
    end

    add_foreign_key :solid_queue_batch_executions, :solid_queue_batches, column: :batch_id, on_delete: :cascade
    add_foreign_key :solid_queue_batch_executions, :solid_queue_jobs, column: :job_id, on_delete: :cascade
  end
end
