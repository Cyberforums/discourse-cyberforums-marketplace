# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::ShopThreads do
  fab!(:merchant, :user)
  fab!(:staff_member, :admin)
  fab!(:shop) { Fabricate(:group, name: "shop-acme", messageable_level: 99) }
  fab!(:other_shop) { Fabricate(:group, name: "shop-other", messageable_level: 99) }

  let(:start) { Time.zone.parse("2026-10-20 01:00:00 UTC") }

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    SiteSetting.tagging_enabled = true
    shop.add(merchant)
  end

  # The chat bridge creates shop conversations as `system` on the buyer's behalf.
  def buyer_pm(title, at:, group: shop)
    freeze_time(at)
    PostCreator.create!(
      Discourse.system_user,
      title: title,
      raw: "买家：请问这个商品还有货吗？",
      archetype: Archetype.private_message,
      target_group_names: [group.name],
      skip_validations: true,
    ).topic
  end

  def reply(topic, user, at:, raw: "商家回复：有货，可以下单。")
    freeze_time(at)
    PostCreator.create!(user, topic_id: topic.id, raw: raw, skip_validations: true)
  end

  def shop_pms(group)
    Topic
      .private_messages
      .joins(:topic_allowed_groups)
      .where(topic_allowed_groups: { group_id: group.id })
  end

  describe ".overdue_topics" do
    it "follows the query 2 rules (merchant replies reset, other staff is neutral)" do
      waiting = buyer_pm("等待中的会话", at: start)
      answered = buyer_pm("已回复的会话", at: start)
      reply(answered, merchant, at: start + 1.hour)
      neutral = buyer_pm("只有管理人员说过话", at: start)
      reply(neutral, staff_member, at: start + 2.hours)
      fresh = buyer_pm("刚来的会话", at: start + 20.hours)
      closed = buyer_pm("已关闭的会话", at: start)
      closed.update!(closed: true)
      again = buyer_pm("回复后买家又问", at: start)
      reply(again, merchant, at: start + 1.hour)
      reply(again, Discourse.system_user, at: start + 2.hours, raw: "买家：还有一个问题")

      rows = described_class.overdue_topics(shop, now: start + 27.hours)
      expect(rows.map(&:topic_id)).to contain_exactly(waiting.id, neutral.id, again.id)
      expect(rows.map(&:topic_id)).not_to include(answered.id, fresh.id, closed.id)
      expect(rows.find { |r| r.topic_id == again.id }.waiting_since).to eq_time(start + 2.hours)
    end

    it "uses the shop's own mc_sla_hours" do
      buyer_pm("慢店会话", at: start)
      shop.custom_fields["mc_sla_hours"] = 48
      shop.save_custom_fields(true)
      expect(described_class.overdue_topics(shop, now: start + 30.hours)).to be_empty
      expect(described_class.overdue_topics(shop, now: start + 49.hours).size).to eq(1)
    end

    it "only looks at the shop's own conversations" do
      buyer_pm("别家的会话", at: start, group: other_shop)
      expect(described_class.overdue_topics(shop, now: start + 30.hours)).to be_empty
    end
  end

  describe ".run_reminders!" do
    it "PMs each shop group once a day and never counts its own reminders" do
      waiting = buyer_pm("等待中的会话", at: start)
      now = start + 30.hours
      freeze_time(now)

      result = described_class.run_reminders!(now: now)
      reminder = result["shop-acme"]
      expect(reminder).to be_a(Topic)
      expect(result["shop-other"]).to eq(:nothing_overdue)
      expect(reminder.allowed_groups).to contain_exactly(shop)
      expect(reminder.title).to include("【超时提醒】", "1 个会话", "24 小时")
      expect(reminder.first_post.raw).to include("/t/#{waiting.id}")
      expect(described_class.internal?(reminder)).to eq(true)

      expect(described_class.run_reminders!(now: now + 1.hour)["shop-acme"]).to eq(:already_sent)

      next_day = now + 1.day
      freeze_time(next_day)
      second = described_class.run_reminders!(now: next_day)["shop-acme"]
      expect(second).to be_a(Topic)
      expect(second.title).to include("1 个会话")
      expect(
        UserHistory
          .where(custom_type: "cyberforums_marketplace_threads")
          .where("details LIKE ?", "%sla_reminder%")
          .count,
      ).to eq(2)
    end

    it "skips disabled shops" do
      buyer_pm("停用店的会话", at: start)
      shop.custom_fields["mc_status"] = "disabled"
      shop.save_custom_fields(true)
      expect(described_class.run_reminders!(now: start + 30.hours)).not_to have_key("shop-acme")
    end
  end

  describe "stale conversations" do
    before do
      SiteSetting.cyberforums_marketplace_stale_enabled = true
      SiteSetting.cyberforums_marketplace_stale_idle_days = 14
    end

    it "tags idle conversations once, posts a note, and clears on the next buyer message" do
      idle = buyer_pm("很久没动的会话", at: start)
      recent = buyer_pm("最近的会话", at: start + 10.days)
      now = start + 15.days
      freeze_time(now)

      expect(described_class.run_stale!(now: now)).to contain_exactly(idle.id)
      idle.reload
      expect(idle.tags.map(&:name)).to include("闲置")
      expect(idle.posts.last.raw).to include("【会话闲置】", "14 天")
      expect(recent.reload.tags).to be_empty
      expect(described_class.run_stale!(now: now + 1.hour)).to be_empty

      # The stale note does not count as a buyer waiting.
      reply(idle, merchant, at: start + 1.hour)
      expect(described_class.overdue_topics(shop, now: now).map(&:topic_id)).not_to include(idle.id)

      reply(idle, Discourse.system_user, at: now + 2.hours, raw: "买家：我又回来了")
      expect(idle.reload.tags.map(&:name)).not_to include("闲置")
    end

    it "does not clear the tag when the feature is off" do
      idle = buyer_pm("很久没动的会话", at: start)
      described_class.run_stale!(now: start + 15.days)
      SiteSetting.cyberforums_marketplace_stale_enabled = false
      reply(idle, Discourse.system_user, at: start + 16.days, raw: "买家：在吗")
      expect(idle.reload.tags.map(&:name)).to include("闲置")
    end

    it "skips internal reminder topics" do
      buyer_pm("等待中的会话", at: start)
      reminder = described_class.send_reminder!(shop, now: start + 30.hours)
      expect(described_class.run_stale!(now: start + 60.days)).not_to include(reminder.id)
    end
  end

  describe "scheduled jobs" do
    it "do nothing while disabled" do
      buyer_pm("等待中的会话", at: start)
      freeze_time(start + 30.hours)
      expect { Jobs::CyberforumsMarketplaceSlaReminders.new.execute({}) }.not_to change {
        shop_pms(shop).count
      }
      expect { Jobs::CyberforumsMarketplaceStaleThreads.new.execute({}) }.not_to change {
        TopicTag.count
      }
    end

    it "run the reminder once a day after the configured Beijing hour" do
      SiteSetting.cyberforums_marketplace_sla_reminders_enabled = true
      SiteSetting.cyberforums_marketplace_sla_reminder_hour = 9
      buyer_pm("等待中的会话", at: start)

      freeze_time(Time.zone.parse("2026-10-22 00:30:00 UTC")) # 08:30 Beijing
      expect { Jobs::CyberforumsMarketplaceSlaReminders.new.execute({}) }.not_to change {
        shop_pms(shop).count
      }

      freeze_time(Time.zone.parse("2026-10-22 01:30:00 UTC")) # 09:30 Beijing
      expect { Jobs::CyberforumsMarketplaceSlaReminders.new.execute({}) }.to change {
        shop_pms(shop).count
      }.by(1)

      freeze_time(Time.zone.parse("2026-10-22 02:30:00 UTC"))
      expect { Jobs::CyberforumsMarketplaceSlaReminders.new.execute({}) }.not_to change {
        shop_pms(shop).count
      }
    end

    it "runs the stale check once a day" do
      SiteSetting.cyberforums_marketplace_stale_enabled = true
      SiteSetting.cyberforums_marketplace_stale_hour = 4
      idle = buyer_pm("很久没动的会话", at: start)
      freeze_time(start + 20.days + 4.hours) # 09:00 Beijing
      Jobs::CyberforumsMarketplaceStaleThreads.new.execute({})
      expect(idle.reload.tags.map(&:name)).to include("闲置")
    end
  end
end
