class AddDisplayNameToIndustryTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :industry_templates, :display_name, :string unless column_exists?(:industry_templates, :display_name)
  end
end