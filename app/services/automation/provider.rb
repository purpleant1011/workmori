module Automation
  # Provider interface. Real Hermes adapter will be plugged in once available;
  # for local/dev we ship a fake in-process adapter.
  class Provider
    KINDS = %w[generate_draft compose_reply search_knowledge schedule_post publish_now run_analysis custom].freeze

    def self.active
      provider_name = ENV.fetch("HERMES_PROVIDER", "fake").downcase
      case provider_name
      when "real" then RealHermesAdapter.new
      else FakeHermesAdapter.new
      end
    end

    def name = raise NotImplementedError
    def execute(rule:, payload:) = raise NotImplementedError
  end
end
