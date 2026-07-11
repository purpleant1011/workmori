class CreateAutomations < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :intent_kind, null: false  # post | reply | report | faq_update | data_export
      t.text    :natural_language
      t.jsonb   :structured_plan, null: false, default: {}
      t.jsonb   :constraints, null: false, default: {}  # 시간, 승인, 비용 한도 등
      t.string  :status, null: false, default: "draft"  # draft | active | paused | archived
      t.references :approved_by_user, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text    :approval_notes
      t.timestamps
    end

    create_table :automation_schedules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_rule, null: false, foreign_key: true
      t.string  :cadence, null: false  # one_off | daily | weekly | monthly | cron
      t.text    :cron_expression
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.boolean :quiet_hours, null: false, default: false
      t.timestamps
    end
    add_index :automation_schedules, :next_run_at

    create_table :automation_executions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_rule, null: false, foreign_key: true
      t.references :ai_employee, null: false, foreign_key: true
      t.string  :state, null: false, default: "draft"  # draft | ready | queued | claimed | running | awaiting_approval | approved | publishing | succeeded | retry_scheduled | failed | cancelled | paused | quarantined | expired
      t.string  :idempotency_key, null: false
      t.text    :error_class
      t.text    :error_message
      t.integer :attempts, null: false, default: 0
      t.integer :max_attempts, null: false, default: 3
      t.datetime :scheduled_at
      t.datetime :claimed_at
      t.datetime :started_at
      t.datetime :finished_at
      t.string  :worker_id
      t.datetime :heartbeat_at
      t.datetime :lease_expires_at
      t.datetime :approval_expires_at
      t.timestamps
    end
    add_index :automation_executions, :idempotency_key, unique: true
    add_index :automation_executions, :scheduled_at

    create_table :execution_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_execution, null: false, foreign_key: true
      t.string  :event_type, null: false
      t.text    :message
      t.jsonb   :payload, null: false, default: {}
      t.string  :actor_kind, null: false, default: "system"  # system | user | worker | operator
      t.timestamps
    end

    create_table :approval_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_execution, foreign_key: true
      t.references :content_item, foreign_key: true
      t.string  :state, null: false, default: "pending"  # pending | approved | rejected | expired
      t.references :requested_from_user, foreign_key: { to_table: :users }
      t.references :decided_by_user, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.text    :decision_notes
      t.datetime :expires_at
      t.timestamps
    end
  end
end
