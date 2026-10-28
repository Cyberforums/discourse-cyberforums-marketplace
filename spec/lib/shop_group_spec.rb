# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::ShopGroup do
  fab!(:verified_group) { Fabricate(:group, name: "deerlogin-verified") }
  fab!(:verified_user, :user)
  fab!(:unverified_user, :user)

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    verified_group.add(verified_user)
  end

  describe "preset on create" do
    it "applies the pilot settings and allows PM tags for a shop group" do
      SiteSetting.pm_tags_allowed_for_groups = "3"
      group = Fabricate(:group, name: "shop-acme")
      group.reload
      expect(group.visibility_level).to eq(Group.visibility_levels[:members])
      expect(group.members_visibility_level).to eq(Group.visibility_levels[:members])
      expect(group.messageable_level).to eq(3)
      expect(group.default_notification_level).to eq(NotificationLevels.all[:watching])
      expect(group.public_admission).to eq(false)
      expect(group.allow_membership_requests).to eq(false)
      expect(SiteSetting.pm_tags_allowed_for_groups.split("|")).to contain_exactly("3", group.id.to_s)
    end

    it "does not duplicate the PM tag entry" do
      group = Fabricate(:group, name: "shop-acme")
      described_class.allow_pm_tags!(group)
      expect(SiteSetting.pm_tags_allowed_for_groups.split("|").count(group.id.to_s)).to eq(1)
    end

    it "leaves other groups alone" do
      group = Fabricate(:group, name: "designers", visibility_level: Group.visibility_levels[:public])
      expect(group.reload.visibility_level).to eq(Group.visibility_levels[:public])
    end

    it "does nothing while the plugin is disabled" do
      SiteSetting.cyberforums_marketplace_enabled = false
      group = Fabricate(:group, name: "shop-off", visibility_level: Group.visibility_levels[:public])
      expect(group.reload.visibility_level).to eq(Group.visibility_levels[:public])
    end
  end

  describe "DeerLogin gate" do
    fab!(:shop) { Fabricate(:group, name: "shop-acme") }

    it "keeps verified users" do
      shop.add(verified_user)
      expect(shop.reload.users).to include(verified_user)
    end

    it "removes unverified users and logs it" do
      shop.add(unverified_user)
      expect(shop.reload.users).not_to include(unverified_user)
      log = UserHistory.where(custom_type: described_class::GATE_LOG).last
      expect(log).to be_present
    end

    it "has no staff bypass" do
      admin = Fabricate(:admin)
      shop.add(admin)
      expect(shop.reload.users).not_to include(admin)
    end

    it "fails closed when the verified group does not exist" do
      SiteSetting.cyberforums_marketplace_verified_group = "missing-group"
      shop.add(verified_user)
      expect(shop.reload.users).not_to include(verified_user)
    end

    it "ignores non-shop groups" do
      other = Fabricate(:group, name: "designers")
      other.add(unverified_user)
      expect(other.reload.users).to include(unverified_user)
    end

    it "removes a user from every shop group when verification is lost" do
      shop2 = Fabricate(:group, name: "shop-beta")
      shop.add(verified_user)
      shop2.add(verified_user)
      verified_group.remove(verified_user)
      expect(shop.reload.users).not_to include(verified_user)
      expect(shop2.reload.users).not_to include(verified_user)
    end
  end
end
