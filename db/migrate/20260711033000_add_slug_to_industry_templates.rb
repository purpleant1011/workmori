class AddSlugToIndustryTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :industry_templates, :slug, :string unless column_exists?(:industry_templates, :slug)
    add_index  :industry_templates, :slug unless index_exists?(:industry_templates, :slug)
  end
end