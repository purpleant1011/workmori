class AddContentItemToAutomationExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_executions, :content_item_id, :bigint
    add_index  :automation_executions, :content_item_id
    add_column :automation_executions, :result_payload_json, :jsonb, default: {}
  end
end
