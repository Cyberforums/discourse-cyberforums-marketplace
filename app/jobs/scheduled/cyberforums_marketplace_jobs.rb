# frozen_string_literal: true

module ::Jobs
  # Per-shop SLA reminders (replaces data-explorer query 2 + automation 20).
  class CyberforumsMarketplaceSlaReminders < ::Jobs::Scheduled
    every 1.hour

    STORE_KEY = "sla_reminders_last_run_date"

    def execute(_args)
      return unless SiteSetting.cyberforums_marketplace_enabled
      return unless SiteSetting.cyberforums_marketplace_sla_reminders_enabled
      threads = ::CyberforumsMarketplace::ShopThreads
      hour = SiteSetting.cyberforums_marketplace_sla_reminder_hour
      return unless threads.due_today?(STORE_KEY, hour)
      threads.run_reminders!
      threads.mark_done_today!(STORE_KEY)
    end
  end

  # Idle shop conversations (replaces /etc/cron.d/marketplace-chat-stale → stale-tick).
  class CyberforumsMarketplaceStaleThreads < ::Jobs::Scheduled
    every 1.hour

    STORE_KEY = "stale_last_run_date"

    def execute(_args)
      return unless SiteSetting.cyberforums_marketplace_enabled
      return unless SiteSetting.cyberforums_marketplace_stale_enabled
      threads = ::CyberforumsMarketplace::ShopThreads
      return unless threads.due_today?(STORE_KEY, SiteSetting.cyberforums_marketplace_stale_hour)
      threads.run_stale!
      threads.mark_done_today!(STORE_KEY)
    end
  end
end
