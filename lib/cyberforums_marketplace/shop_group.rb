# frozen_string_literal: true

module ::CyberforumsMarketplace
  module ShopGroup
    GATE_LOG = "cyberforums_marketplace_gate"

    def self.prefix
      SiteSetting.cyberforums_marketplace_shop_group_prefix.to_s.presence || "shop-"
    end

    def self.shop_group?(group)
      group.present? && !group.automatic && group.name.to_s.start_with?(prefix)
    end

    def self.shop_groups
      Group.where(automatic: false).where("name LIKE ?", "#{Group.sanitize_sql_like(prefix)}%").order(:name)
    end

    def self.verified_group
      name = SiteSetting.cyberforums_marketplace_verified_group.to_s.strip
      name.present? ? Group.find_by(name: name) : nil
    end

    def self.verified_user_ids
      g = verified_group
      g ? g.group_users.pluck(:user_id).to_set : Set.new
    end

    # Fail closed: missing verified group = nobody counts as verified.
    def self.verified?(user)
      g = verified_group
      g.present? && user.present? && g.group_users.exists?(user_id: user.id)
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

    # DeerLogin gate: only verified users may stay in a shop group. No bypass for staff.
    def self.enforce_verified!(user, group)
      return false unless shop_group?(group)
      return false if verified?(user)
      group.remove(user)
      log_gate(user, group, "removed_unverified")
      true
    end

    # Losing verification removes the user from every shop group.
    def self.on_left_verified_group!(user, group)
      vg = verified_group
      return [] if vg.nil? || group.id != vg.id
      removed = []
      shop_groups.joins(:group_users).where(group_users: { user_id: user.id }).each do |g|
        g.remove(user)
        log_gate(user, g, "removed_lost_verification")
        removed << g.name
      end
      removed
    end

    def self.log_gate(user, group, action)
      Rails.logger.warn("[cyberforums-marketplace] #{action} user=#{user.username} group=#{group.name}")
      StaffActionLogger.new(Discourse.system_user).log_custom(
        GATE_LOG,
        { action: action, username: user.username, group: group.name },
      )
    rescue StandardError => e
      Rails.logger.warn("[cyberforums-marketplace] gate log failed: #{e.class}")
    end
  end
end
