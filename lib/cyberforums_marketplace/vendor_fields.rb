# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Shop metadata stored as group custom fields.
  #
  # Two kinds of fields:
  # - ADMIN_EDITABLE: forum-side service settings (chat on/off, SLA, limits).
  # - SYNCED: written only by the WooCommerce sync; WooCommerce is the source
  #   of truth, so they are not editable from the group settings API.
  module VendorFields
    TYPES = {
      "mc_vendor_id" => :string,
      "mc_enabled" => :boolean,
      "mc_display_name" => :string,
      "mc_sla_hours" => :integer,
      "mc_order_sla_hours" => :integer,
      "mc_rate_limit" => :integer,
      "mc_wp_store_id" => :string,
      "mc_brand" => :string,
      "mc_product_hint" => :string,
      "mc_source" => :string,
      "mc_status" => :string,
      "mc_wc_store_slug" => :string,
      "mc_wc_synced_at" => :string,
      "mc_owner_pending" => :boolean,
      "mc_owner_email_masked" => :string,
    }.freeze

    ADMIN_EDITABLE = %w[
      mc_enabled
      mc_sla_hours
      mc_order_sla_hours
      mc_rate_limit
      mc_brand
      mc_product_hint
    ].freeze

    STATUS_ACTIVE = "active"
    STATUS_DISABLED = "disabled"

    VENDOR_ID_RE = /\A[a-z0-9](?:[a-z0-9-]{0,13}[a-z0-9])?\z/
    DEFAULT_SLA_HOURS = 24

    def self.vendor_id_for(group)
      raw = group.custom_fields["mc_vendor_id"].to_s.strip
      raw.presence || group.name.to_s.delete_prefix(ShopGroup.prefix)
    end

    def self.int_or_nil(val)
      return nil if val.nil? || val.to_s.strip.empty?
      i = Integer(val.to_s, exception: false)
      i && i > 0 ? i : nil
    end

    def self.truthy?(val)
      val == true || %w[t true 1 yes].include?(val.to_s.strip.downcase)
    end

    def self.status_for(group)
      group.custom_fields["mc_status"].to_s == STATUS_DISABLED ? STATUS_DISABLED : STATUS_ACTIVE
    end

    def self.disabled?(group)
      status_for(group) == STATUS_DISABLED
    end

    # Validation problems; an enabled shop with problems is reported as not servable.
    def self.problems_for(group)
      out = []
      vid = vendor_id_for(group)
      out << "vendor_id_invalid" unless VENDOR_ID_RE.match?(vid)
      expected = "#{ShopGroup.prefix}#{vid}"
      if group.custom_fields["mc_vendor_id"].present? && group.name != expected
        out << "group_name_mismatch"
      end
      %w[mc_sla_hours mc_order_sla_hours mc_rate_limit].each do |f|
        raw = group.custom_fields[f]
        out << "#{f}_invalid" if raw.present? && int_or_nil(raw).nil?
      end
      out << "no_owner" if group.group_users.where(owner: true).none?
      out
    end

    # Informational only (do not block the shop).
    def self.notices_for(group)
      out = []
      out << "owner_pending" if truthy?(group.custom_fields["mc_owner_pending"])
      slug = group.custom_fields["mc_wc_store_slug"].to_s
      out << "store_slug_changed" if slug.present? && slug != vendor_id_for(group)
      out
    end

    def self.for_group(group)
      sla = int_or_nil(group.custom_fields["mc_sla_hours"]) || DEFAULT_SLA_HOURS
      problems = problems_for(group)
      status = status_for(group)
      {
        vendor_id: vendor_id_for(group),
        group_id: group.id,
        group_name: group.name,
        status: status,
        source: group.custom_fields["mc_source"].to_s.presence || "forum",
        enabled:
          truthy?(group.custom_fields["mc_enabled"]) && status == STATUS_ACTIVE && problems.empty?,
        display_name:
          group.custom_fields["mc_display_name"].presence || group.full_name.presence || group.name,
        sla_hours: sla,
        order_sla_hours: int_or_nil(group.custom_fields["mc_order_sla_hours"]) || sla,
        rate_limit: int_or_nil(group.custom_fields["mc_rate_limit"]),
        wp_store_id: group.custom_fields["mc_wp_store_id"].to_s,
        brand: group.custom_fields["mc_brand"].to_s,
        product_hint: group.custom_fields["mc_product_hint"].to_s,
        wc_synced_at: group.custom_fields["mc_wc_synced_at"].to_s.presence,
        owner_pending: truthy?(group.custom_fields["mc_owner_pending"]),
        owner_email_masked: group.custom_fields["mc_owner_email_masked"].to_s.presence,
        problems: problems,
        notices: notices_for(group),
      }
    end

    # Full record for the bridge (admin only): adds staff with roles.
    def self.for_bridge(group)
      staff =
        group
          .group_users
          .includes(:user)
          .order(:created_at)
          .filter_map do |gu|
            next if gu.user.nil?
            { username: gu.user.username, role: gu.owner ? "owner" : "agent" }
          end
      for_group(group).merge(staff: staff)
    end
  end
end
