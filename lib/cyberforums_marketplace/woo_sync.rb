# frozen_string_literal: true

require "openssl"
require "base64"

module ::CyberforumsMarketplace
  # Applies one merchant snapshot sent by the WordPress plugin
  # wenpai-marketplace-forum-sync through a native WooCommerce webhook.
  #
  # Rules (Feng 2026-10-29):
  # - WooCommerce (MarketKing manual review) decides who has a shop; no DeerLogin gate here.
  # - Merchant ↔ forum account by email; no match → mark pending, never create accounts.
  # - Merchant disabled/deleted → only mark the group disabled and hide it from the list.
  #   Members are never removed and groups are never deleted.
  module WooSync
    SCHEMA = "wenpai-marketplace-forum-sync/1"
    TOPIC = "marketking_vendor.updated"
    LOG_TYPE = "cyberforums_marketplace_woo"
    STORE_KEY_LAST = "woo_last_received_at"
    STORE_KEY_RECONCILE = "woo_last_reconcile_at"

    class Invalid < StandardError
    end

    def self.expected_signature(raw_body, secret)
      Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret.to_s, raw_body.to_s))
    end

    def self.valid_signature?(raw_body, header, secret)
      return false if secret.to_s.empty? || header.to_s.empty?
      ActiveSupport::SecurityUtils.secure_compare(
        expected_signature(raw_body, secret),
        header.to_s.strip,
      )
    end

    # WooCommerce sends an unsigned "webhook_id=<id>" ping when a webhook is saved.
    def self.ping?(raw_body)
      raw_body.to_s.strip.match?(/\Awebhook_id=\d+\z/)
    end

    def self.normalize_slug(raw)
      raw.to_s.strip.downcase.gsub(/[^a-z0-9-]+/, "-").gsub(/-{2,}/, "-").gsub(/\A-+|-+\z/, "")
    end

    def self.max_slug_length
      [SiteSetting.max_username_length.to_i - ShopGroup.prefix.length, 15].min
    end

    def self.mask_email(email)
      local, domain = email.to_s.split("@", 2)
      return "" if local.to_s.empty? || domain.to_s.empty?
      host, _, tld = domain.rpartition(".")
      host = domain if host.empty?
      masked_domain = "#{host[0]}***#{tld.empty? ? "" : ".#{tld}"}"
      "#{local[0]}***@#{masked_domain}"
    end

    # Only real, active, confirmed accounts can become shop owners.
    def self.match_user(email)
      email = email.to_s.strip.downcase
      return nil if email.empty?
      user = UserEmail.find_by(email: email)&.user
      return nil if user.nil? || user.staged || !user.active || user.suspended?
      user
    end

    def self.group_for_wp_user(wp_user_id)
      ids =
        GroupCustomField
          .where(name: "mc_wp_store_id", value: wp_user_id.to_s)
          .order(:group_id)
          .pluck(:group_id)
      ids.empty? ? nil : Group.find_by(id: ids.first)
    end

    def self.truthy?(val)
      VendorFields.truthy?(val)
    end

    def self.parse!(payload)
      raise Invalid, "payload_not_object" unless payload.is_a?(Hash)
      raise Invalid, "schema_unsupported" unless payload["schema"].to_s == SCHEMA
      vendor = payload["vendor"]
      raise Invalid, "vendor_missing" unless vendor.is_a?(Hash)
      wp_user_id = Integer(vendor["wp_user_id"].to_s, exception: false)
      raise Invalid, "wp_user_id_invalid" if wp_user_id.nil? || wp_user_id <= 0
      generated_at =
        begin
          Time.iso8601(payload["generated_at"].to_s)
        rescue ArgumentError
          raise Invalid, "generated_at_invalid"
        end
      event = payload["event"].to_s
      raise Invalid, "event_unsupported" if %w[vendor.updated vendor.deleted].exclude?(event)
      active =
        event == "vendor.updated" && truthy?(vendor["approved"]) && truthy?(vendor["is_vendor"])
      {
        wp_user_id: wp_user_id,
        generated_at: generated_at,
        event: event,
        reason: payload["reason"].to_s,
        active: active,
        email: vendor["email"].to_s.strip.downcase,
        store_name: vendor["store_name"].to_s.strip,
        slug: normalize_slug(vendor["store_slug"]),
      }
    end

    def self.apply!(payload)
      data = parse!(payload)
      DistributedMutex.synchronize(
        "cyberforums_marketplace_woo_#{data[:wp_user_id]}",
        validity: 30,
      ) do
        result = apply_locked(data)
        record_received!(data)
        result
      end
    end

    def self.record_received!(data)
      now = Time.zone.now.iso8601
      PluginStore.set(PLUGIN_NAME, STORE_KEY_LAST, now)
      PluginStore.set(PLUGIN_NAME, STORE_KEY_RECONCILE, now) if data[:reason] == "reconcile"
    end

    def self.status
      last = PluginStore.get(PLUGIN_NAME, STORE_KEY_LAST)
      reconcile = PluginStore.get(PLUGIN_NAME, STORE_KEY_RECONCILE)
      stale =
        begin
          reconcile.nil? || Time.iso8601(reconcile.to_s) < 36.hours.ago
        rescue ArgumentError
          true
        end
      {
        webhook_enabled: SiteSetting.cyberforums_marketplace_woo_webhook_enabled,
        last_received_at: last,
        last_reconcile_at: reconcile,
        reconcile_stale: stale,
      }
    end

    def self.apply_locked(data)
      group = group_for_wp_user(data[:wp_user_id])
      created = false

      if group.nil?
        # Pending/disabled merchants that never had a shop: nothing to mirror.
        return { result: "ignored", reason: "not_approved" } unless data[:active]

        slug = data[:slug]
        return reject(data, "store_slug_missing") if slug.empty?
        return reject(data, "store_slug_too_long") if slug.length > max_slug_length
        return reject(data, "store_slug_invalid") unless VendorFields::VENDOR_ID_RE.match?(slug)

        name = "#{ShopGroup.prefix}#{slug}"
        group = Group.where("LOWER(name) = ?", name.downcase).first
        if group
          other = group.custom_fields["mc_wp_store_id"].to_s
          if other.present? && other != data[:wp_user_id].to_s
            return reject(data, "store_slug_taken")
          end
          return reject(data, "group_not_shop") unless ShopGroup.shop_group?(group)
        else
          begin
            group = Group.new(name: name, full_name: data[:store_name].presence&.slice(0, 100))
            group.assign_attributes(ShopGroup.preset_attributes)
            group.save!
          rescue ActiveRecord::RecordInvalid => e
            return reject(data, "group_invalid: #{e.record.errors.full_messages.join("; ")}")
          end
          created = true
        end
        ShopGroup.allow_pm_tags!(group)
      end

      last = group.custom_fields["mc_wc_synced_at"].to_s
      if last.present?
        last_t =
          begin
            Time.iso8601(last)
          rescue ArgumentError
            nil
          end
        if last_t && data[:generated_at] < last_t
          return { result: "stale_ignored", group: group.name }
        end
      end

      cf = group.custom_fields
      cf["mc_source"] = "woocommerce"
      cf["mc_wp_store_id"] = data[:wp_user_id].to_s
      cf["mc_wc_store_slug"] = data[:slug] if data[:slug].present?
      cf["mc_wc_synced_at"] = data[:generated_at].utc.iso8601
      cf["mc_display_name"] = data[:store_name] if data[:store_name].present?

      owner = "unchanged"
      if data[:active]
        cf["mc_status"] = VendorFields::STATUS_ACTIVE
        if data[:store_name].present? && group.full_name != data[:store_name].slice(0, 100)
          group.update!(full_name: data[:store_name].slice(0, 100))
        end
        user = match_user(data[:email])
        if user
          gu = group.group_users.find_by(user_id: user.id)
          group.add_owner(user) unless gu&.owner
          owner = gu&.owner ? "already_owner" : "added"
          cf["mc_owner_pending"] = false
          cf["mc_owner_email_masked"] = nil
        else
          owner = "pending"
          cf["mc_owner_pending"] = true
          cf["mc_owner_email_masked"] = mask_email(data[:email])
        end
      else
        cf["mc_status"] = VendorFields::STATUS_DISABLED
      end
      group.save_custom_fields(true)

      action =
        if created
          "created"
        elsif data[:active]
          "updated"
        else
          "disabled"
        end
      log(action, data, group, owner: owner)
      {
        result: "applied",
        action: action,
        group: group.name,
        status: VendorFields.status_for(group),
        owner: owner,
      }
    end

    def self.reject(data, reason)
      log("rejected", data, nil, reason: reason)
      { result: "rejected", reason: reason }
    end

    def self.log(action, data, group, extra = {})
      details = {
        action: action,
        wp_user_id: data[:wp_user_id],
        group: group&.name,
        reason: data[:reason],
      }.merge(extra).compact
      Rails.logger.info("[cyberforums-marketplace] woo #{details.to_json}")
      StaffActionLogger.new(Discourse.system_user).log_custom(LOG_TYPE, details)
    rescue StandardError => e
      Rails.logger.warn("[cyberforums-marketplace] woo log failed: #{e.class}")
    end
  end
end
