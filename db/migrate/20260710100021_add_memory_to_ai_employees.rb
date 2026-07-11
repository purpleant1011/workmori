class AddMemoryToAiEmployees < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_employees, :memory_json, :jsonb, default: { notes: [], topics: [], style_examples: [] }, null: false
    add_column :ai_employees, :persona_preset, :string
    add_column :ai_employees, :last_memory_extracted_at, :datetime
  end
end
