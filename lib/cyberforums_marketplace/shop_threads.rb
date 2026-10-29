# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Buyer ↔ shop conversations are private messages whose allowed groups include
  # the shop group (the chat bridge creates them as `system` on the buyer's behalf).
  #
  # Phase 2 (replaces scripts / per-shop automations, see design doc §8):
  # - SLA reminders: per-shop `mc_sla_hours`, one PM per shop per day
  #   (replaces data-explorer query 2 + automation 20, which were cloned per shop).
  # - Stale threads: tag idle conversations and add a short note
  #   (replaces the bridge's /etc/cron.d/marketplace-chat-stale → stale-tick).
  module ShopThreads
    TIMEZONE = "Asia/Shanghai"
    INTERNAL_FIELD = "mc_internal"
    STALE_MARKER = "【会话闲置】"
    REMINDER_MARKER = "【超时提醒】"
    # Same neutral notices as the bridge / query 2.
    NEUTRAL_RE = "(【平台介入】|会话合并|会话闲置|【超时提醒】)"

    def self.now_local(now = Time.zone.now)
      now.in_time_zone(TIMEZONE)
    end

    def self.active_shop_groups
      ShopGroup.shop_groups.reject { |g| VendorFields.disabled?(g) }
    end

    def self.sla_hours_for(group)
      VendorFields.int_or_nil(group.custom_fields["mc_sla_hours"]) ||
        VendorFields::DEFAULT_SLA_HOURS
    end

    # Rule (same as query 2): shop member post = merchant; platform notices,
    # discobot and other staff = neutral; everything else (including `system`
    # posting buyer messages for the bridge) = buyer. Waiting starts at the first
    # buyer post after the latest merchant post.
    OVERDUE_SQL = <<~SQL
      WITH t AS (
        SELECT tp.id, tp.title
        FROM topics tp
        JOIN topic_allowed_groups tag ON tag.topic_id = tp.id AND tag.group_id = :group_id
        WHERE tp.archetype = 'private_message' AND tp.deleted_at IS NULL
          AND NOT tp.closed AND NOT tp.archived
          AND NOT EXISTS (
            SELECT 1 FROM topic_custom_fields tcf
            WHERE tcf.topic_id = tp.id AND tcf.name = :internal_field
          )
      ),
      p AS (
        SELECT po.topic_id, po.created_at,
          CASE
            WHEN EXISTS (SELECT 1 FROM group_users gu WHERE gu.group_id = :group_id AND gu.user_id = po.user_id) THEN 'merchant'
            WHEN po.user_id = -2 OR po.raw ~ :neutral_re THEN 'neutral'
            WHEN po.user_id > 0 AND EXISTS (SELECT 1 FROM users u WHERE u.id = po.user_id AND (u.admin OR u.moderator)) THEN 'neutral'
            ELSE 'buyer'
          END AS side
        FROM posts po JOIN t ON t.id = po.topic_id
        WHERE po.deleted_at IS NULL AND po.post_type = 1
      ),
      lm AS (SELECT topic_id, max(created_at) AS last_merchant FROM p WHERE side = 'merchant' GROUP BY topic_id),
      w AS (
        SELECT p.topic_id, min(p.created_at) AS waiting_since
        FROM p LEFT JOIN lm ON lm.topic_id = p.topic_id
        WHERE p.side = 'buyer' AND (lm.last_merchant IS NULL OR p.created_at > lm.last_merchant)
        GROUP BY p.topic_id
      )
      SELECT t.id AS topic_id, t.title, w.waiting_since
      FROM w JOIN t ON t.id = w.topic_id
      WHERE w.waiting_since < :cutoff
      ORDER BY w.waiting_since, t.id
    SQL

    def self.overdue_topics(group, hours: sla_hours_for(group), now: Time.zone.now)
      DB.query(
        OVERDUE_SQL,
        group_id: group.id,
        internal_field: INTERNAL_FIELD,
        neutral_re: NEUTRAL_RE,
        cutoff: now - hours.hours,
      )
    end

    STALE_SQL = <<~SQL
      SELECT tp.id
      FROM topics tp
      JOIN topic_allowed_groups tag ON tag.topic_id = tp.id AND tag.group_id = :group_id
      WHERE tp.archetype = 'private_message' AND tp.deleted_at IS NULL
        AND NOT tp.closed AND NOT tp.archived
        AND NOT EXISTS (
          SELECT 1 FROM topic_custom_fields tcf
          WHERE tcf.topic_id = tp.id AND tcf.name = :internal_field
        )
        AND NOT EXISTS (
          SELECT 1 FROM topic_tags tt JOIN tags tg ON tg.id = tt.tag_id
          WHERE tt.topic_id = tp.id AND lower(tg.name) = lower(:tag)
        )
        AND (
          SELECT max(po.created_at) FROM posts po
          WHERE po.topic_id = tp.id AND po.deleted_at IS NULL AND po.post_type = 1
        ) < :cutoff
      ORDER BY tp.id
    SQL

    def self.stale_tag_name
      SiteSetting.cyberforums_marketplace_stale_tag.to_s.strip.presence || "闲置"
    end

    def self.stale_idle_days
      [SiteSetting.cyberforums_marketplace_stale_idle_days.to_i, 1].max
    end

    def self.stale_candidates(group, now: Time.zone.now)
      DB.query_single(
        STALE_SQL,
        group_id: group.id,
        internal_field: INTERNAL_FIELD,
        tag: stale_tag_name,
        cutoff: now - stale_idle_days.days,
      )
    end

    def self.shop_pm?(topic)
      topic&.private_message? && topic.allowed_groups.any? { |g| ShopGroup.shop_group?(g) }
    end

    def self.internal?(topic)
      VendorFields.truthy?(topic.custom_fields[INTERNAL_FIELD])
    end

    def self.find_or_create_stale_tag!
      name = stale_tag_name
      Tag.where("lower(name) = ?", name.downcase).first || Tag.create!(name: name)
    end

    def self.has_tag?(topic, name)
      topic.tags.any? { |t| t.name.casecmp?(name) }
    end

    def self.mark_stale!(topic)
      tag = find_or_create_stale_tag!
      return false if has_tag?(topic, tag.name)
      TopicTag.find_or_create_by!(topic_id: topic.id, tag_id: tag.id)
      days = stale_idle_days
      PostCreator.create!(
        Discourse.system_user,
        topic_id: topic.id,
        raw: "**#{STALE_MARKER}** 超过 #{days} 天无新消息，已标为闲置。买家再发消息将自动恢复。",
        skip_validations: true,
        import_mode: false,
      )
      log("stale", topic: topic.id, idle_days: days)
      true
    end

    def self.unmark_stale!(topic)
      tag = Tag.where("lower(name) = ?", stale_tag_name.downcase).first
      return false if tag.nil?
      removed = TopicTag.where(topic_id: topic.id, tag_id: tag.id).destroy_all
      return false if removed.empty?
      log("stale_cleared", topic: topic.id)
      true
    end

    # Called from :post_created. A new regular post (other than our own notes)
    # in a stale shop conversation clears the stale tag.
    def self.on_post_created(post)
      return unless SiteSetting.cyberforums_marketplace_enabled
      return unless SiteSetting.cyberforums_marketplace_stale_enabled
      return if post.nil? || post.post_type != Post.types[:regular]
      return if post.raw.to_s.include?(STALE_MARKER)
      topic = post.topic
      return unless shop_pm?(topic)
      return unless has_tag?(topic, stale_tag_name)
      unmark_stale!(topic)
    end

    def self.run_stale!(now: Time.zone.now)
      marked = []
      active_shop_groups.each do |group|
        stale_candidates(group, now: now).each do |topic_id|
          topic = Topic.find_by(id: topic_id)
          next if topic.nil?
          marked << topic.id if mark_stale!(topic)
        end
      end
      PluginStore.set(PLUGIN_NAME, "stale_last_run_at", now.utc.iso8601)
      marked
    end

    def self.escape_cell(text)
      text.to_s.gsub(/[|\[\]\r\n]/, "|" => "｜", "[" => "【", "]" => "】", "\r" => " ", "\n" => " ")
    end

    def self.reminder_raw(group, rows, hours, now)
      local = now_local(now)
      lines = []
      lines << "**#{REMINDER_MARKER}** 以下 #{rows.size} 个买家会话超过 #{hours} 小时没有商家回复（北京时间 #{local.strftime("%Y-%m-%d %H:%M")} 统计）："
      lines << ""
      lines << "| 会话 | 买家等待起点（北京时间） | 已等小时 |"
      lines << "|---|---|---|"
      rows.each do |r|
        since = r.waiting_since.in_time_zone(TIMEZONE)
        waited = ((now - r.waiting_since) / 3600).floor
        lines << "| [#{escape_cell(r.title)}](/t/#{r.topic_id}) | #{since.strftime("%Y-%m-%d %H:%M")} | #{waited} |"
      end
      lines << ""
      lines << "SLA 来自店铺资料 `mc_sla_hours`（未填按 #{VendorFields::DEFAULT_SLA_HOURS} 小时）。回复买家后，该会话不再出现在提醒里。"
      lines.join("\n")
    end

    def self.reminder_store_key(group)
      "sla_reminder_last_date:#{group.id}"
    end

    # Sends at most one reminder PM per shop group per local day.
    def self.send_reminder!(group, now: Time.zone.now)
      today = now_local(now).to_date.iso8601
      return :already_sent if PluginStore.get(PLUGIN_NAME, reminder_store_key(group)) == today
      hours = sla_hours_for(group)
      rows = overdue_topics(group, hours: hours, now: now)
      return :nothing_overdue if rows.empty?
      name =
        group.custom_fields["mc_display_name"].presence || group.full_name.presence || group.name
      post =
        PostCreator.create!(
          Discourse.system_user,
          title: "#{REMINDER_MARKER}#{name}：#{rows.size} 个会话超过 #{hours} 小时未回复（#{today}）",
          raw: reminder_raw(group, rows, hours, now),
          archetype: Archetype.private_message,
          target_group_names: [group.name],
          skip_validations: true,
        )
      post.topic.custom_fields[INTERNAL_FIELD] = true
      post.topic.save_custom_fields(true)
      PluginStore.set(PLUGIN_NAME, reminder_store_key(group), today)
      log("sla_reminder", group: group.name, overdue: rows.size, hours: hours, topic: post.topic_id)
      post.topic
    end

    def self.run_reminders!(now: Time.zone.now)
      active_shop_groups.each_with_object({}) do |group, out|
        out[group.name] = send_reminder!(group, now: now)
      end
    end

    # Hourly jobs run their daily task once the local hour has been reached.
    def self.due_today?(store_key, hour, now: Time.zone.now)
      local = now_local(now)
      return false if local.hour < hour.to_i.clamp(0, 23)
      PluginStore.get(PLUGIN_NAME, store_key) != local.to_date.iso8601
    end

    def self.mark_done_today!(store_key, now: Time.zone.now)
      PluginStore.set(PLUGIN_NAME, store_key, now_local(now).to_date.iso8601)
    end

    def self.log(action, details)
      UserHistory.create!(
        action: UserHistory.actions[:custom_staff],
        custom_type: "cyberforums_marketplace_threads",
        details: details.merge(action: action).map { |k, v| "#{k}: #{v}" }.join("\n"),
      )
    end
  end
end
