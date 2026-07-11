class AddIndustryKindToIndustryTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :industry_templates, :industry_kind, :string unless column_exists?(:industry_templates, :industry_kind)
  end
end