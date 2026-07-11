class AddLocaleToAiAndConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_employees, :preferred_locale, :string, default: "auto", null: false
    add_column :ai_employees, :supported_locales, :string, default: "ko,en", null: false
    add_column :ai_employees, :fallback_locale,  :string, default: "ko", null: false

    add_column :conversations, :detected_locale, :string, default: "ko", null: false
    add_column :conversations, :response_locale, :string, default: "ko", null: false
  end
end