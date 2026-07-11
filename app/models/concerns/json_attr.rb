# Tiny helper to read/write JSON columns with array-or-hash defaults.
module JsonAttr
  extend ActiveSupport::Concern

  class_methods do
    def json_attr(column, default: [])
      define_method(column) do
        raw = read_attribute(column)
        raw.nil? ? default_for(default) : raw
      end

      define_method("#{column}=") do |val|
        write_attribute(column, val)
      end
    end
  end

  def default_for(d)
    d.is_a?(Proc) ? d.call : d.deep_dup
  end
end
