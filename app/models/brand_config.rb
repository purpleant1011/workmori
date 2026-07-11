class BrandConfig
  include Singleton
  CONFIG_PATH = Rails.root.join("config", "branding.yml")
  attr_reader :data

  def initialize
    raw = YAML.load_file(CONFIG_PATH, aliases: true).with_indifferent_access
    @data = (raw[Rails.env] || raw["development"]).with_indifferent_access
  end

  def method_missing(name, *args)
    return @data[name] if @data.key?(name)
    super
  end

  def respond_to_missing?(name, include_private = false)
    @data.key?(name) || super
  end
end
