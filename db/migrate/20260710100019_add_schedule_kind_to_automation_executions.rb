class AddScheduleKindToAutomationExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_executions, :schedule_kind, :string, default: "manual", null: false
    add_column :automation_executions, :trigger_kind, :string, default: "time", null: false
    add_column :automation_executions, :input_json, :jsonb, default: {}
    add_column :automation_executions, :output_json, :jsonb, default: {}
    add_index  :automation_executions, :state
  end
end
