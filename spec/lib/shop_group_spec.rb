# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::ShopGroup do
  fab!(:user)

  before { SiteSetting.cyberforums_marketplace_enabled = true }

  it "recognises shop groups by prefix" do
    expect(described_class.shop_group?(Fabricate(:group, name: "shop-acme"))).to eq(true)
    expect(described_class.shop_group?(Fabricate(:group, name: "designers"))).to eq(false)
  end

  it "applies the pilot settings and allows PM tags" do
    SiteSetting.pm_tags_allowed_for_groups = "3"
    group = Fabricate(:group, name: "shop-acme", visibility_level: Group.visibility_levels[:public])
    described_class.apply_preset!(group)
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
    described_class.allow_pm_tags!(group)
    expect(SiteSetting.pm_tags_allowed_for_groups.split("|").count(group.id.to_s)).to eq(1)
  end

  it "does not touch groups created in the forum (the forum is not a shop entry point)" do
    group =
      Fabricate(:group, name: "shop-manual", visibility_level: Group.visibility_levels[:public])
    expect(group.reload.visibility_level).to eq(Group.visibility_levels[:public])
  end

  it "never removes anyone from a shop group (no real-name gate)" do
    shop = Fabricate(:group, name: "shop-acme")
    shop.add(user)
    admin = Fabricate(:admin)
    shop.add(admin)
    expect(shop.reload.users).to include(user, admin)
    expect(SiteSetting.respond_to?(:cyberforums_marketplace_verified_group)).to eq(false)
  end
end
