class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :weekly_reports do |t|
      t.references :account, null: false, foreign_key: true
      t.date    :week_start_on, null: false
      t.date    :week_end_on, null: false
      t.integer :content_created_count, null: false, default: 0
      t.integer :content_approved_count, null: false, default: 0
      t.integer :content_published_count, null: false, default: 0
      t.integer :content_failed_count, null: false, default: 0
      t.integer :inquiry_count, null: false, default: 0
      t.integer :handoff_count, null: false, default: 0
      t.integer :ai_token_used, null: false, default: 0
      t.integer :ai_cost_krw, null: false, default: 0
      t.text    :summary
      t.text    :improvement_suggestions
      t.jsonb   :top_topics, null: false, default: []
      t.jsonb   :missing_knowledge, null: false, default: []
      t.string  :state, null: false, default: "draft"  # draft | ready | archived
      t.timestamps
    end
  end
end
