# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::VendorFields do
  fab!(:verified_group) { Fabricate(:group, name: "deerlogin-verified") }
  fab!(:owner, :user)
  fab!(:shop) { Fabricate(:group, name: "shop-acme", full_name: "Acme 店") }

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    verified_group.add(owner)
    shop.add_owner(owner)
  end

  it "derives vendor id from the group name and applies defaults" do
    data = described_class.for_group(shop)
    expect(data[:vendor_id]).to eq("acme")
    expect(data[:sla_hours]).to eq(24)
    expect(data[:order_sla_hours]).to eq(24)
    expect(data[:display_name]).to eq("Acme 店")
    expect(data[:enabled]).to eq(false)
  end

  it "is enabled only when mc_enabled is set and there are no problems" do
    shop.custom_fields["mc_enabled"] = true
    shop.custom_fields["mc_sla_hours"] = 12
    shop.save_custom_fields
    data = described_class.for_group(shop.reload)
    expect(data[:enabled]).to eq(true)
    expect(data[:sla_hours]).to eq(12)
    expect(data[:order_sla_hours]).to eq(12)
  end

  it "reports problems and refuses to enable a broken shop" do
    shop.custom_fields["mc_enabled"] = true
    shop.custom_fields["mc_vendor_id"] = "other"
    shop.custom_fields["mc_rate_limit"] = "abc"
    shop.save_custom_fields
    data = described_class.for_group(shop.reload)
    expect(data[:problems]).to include("group_name_mismatch", "mc_rate_limit_invalid")
    expect(data[:enabled]).to eq(false)
  end

  it "flags a shop without an owner" do
    lonely = Fabricate(:group, name: "shop-lonely")
    expect(described_class.problems_for(lonely)).to include("no_owner")
  end

  it "lists staff with roles and verification for the bridge" do
    data = described_class.for_bridge(shop)
    expect(data[:staff]).to contain_exactly({ username: owner.username, role: "owner", deerlogin_verified: true })
  end
end
