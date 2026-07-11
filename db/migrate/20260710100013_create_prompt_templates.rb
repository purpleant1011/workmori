class CreatePromptTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_templates do |t|
      t.string  :name, null: false                # byreum_content_generator, byreum_inquiry_classifier 등
      t.string  :version, null: false
      t.string  :purpose
      t.text    :system_prompt
      t.text    :user_prompt_template
      t.text    :output_schema
      t.boolean :active, null: false, default: false
      t.timestamps
    end

    create_table :industry_templates do |t|
      t.string  :industry_code, null: false
      t.string  :version, null: false
      t.jsonb   :starter_brand_profile, null: false, default: {}
      t.jsonb   :starter_ai_employee, null: false, default: {}
      t.jsonb   :starter_automations, null: false, default: []
      t.jsonb   :starter_guardrails, null: false, default: []
      t.timestamps
    end
  end
end
