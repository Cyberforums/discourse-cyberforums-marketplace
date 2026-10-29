# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Shop groups (shop-<slug>) mirror approved merchants of the WooCommerce
  # marketplace (MarketKing). The forum is not a place to open shops: groups are
  # created/updated only by the signed WooCommerce webhook (see WooSync).
  module ShopGroup
    def self.prefix
      SiteSetting.cyberforums_marketplace_shop_group_prefix.to_s.presence || "shop-"
    end

    def self.shop_group?(group)
      group.present? && !group.automatic && group.name.to_s.start_with?(prefix)
    end

    def self.shop_groups
      Group
        .where(automatic: false)
        .where("name LIKE ?", "#{Group.sanitize_sql_like(prefix)}%")
        .order(:name)
    end

    # Same settings as the 10-28 pilot group shop-demo-wenpai (admin-changes doc §1).
    def self.preset_attributes
      {
        visibility_level: Group.visibility_levels[:members],
        members_visibility_level: Group.visibility_levels[:members],
        mentionable_level: Group::ALIAS_LEVELS[:mods_and_admins],
        messageable_level: SiteSetting.cyberforums_marketplace_shop_messageable_level.to_i,
        default_notification_level: NotificationLevels.all[:watching],
        public_admission: false,
        public_exit: false,
        allow_membership_requests: false,
      }
    end

    def self.apply_preset!(group)
      group.update!(preset_attributes)
      allow_pm_tags!(group)
      group
    end

    def self.allow_pm_tags!(group)
      ids = SiteSetting.pm_tags_allowed_for_groups.to_s.split("|").map(&:strip).reject(&:empty?)
      return if ids.include?(group.id.to_s)
      SiteSetting.pm_tags_allowed_for_groups = (ids + [group.id.to_s]).join("|")
    end
  end
end
