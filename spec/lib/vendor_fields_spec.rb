# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::VendorFields do
  fab!(:owner, :user)
  fab!(:shop) { Fabricate(:group, name: "shop-acme", full_name: "Acme 店") }

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    shop.add_owner(owner)
  end

  it "derives vendor id from the group name and applies defaults" do
    data = described_class.for_group(shop)
    expect(data[:vendor_id]).to eq("acme")
    expect(data[:sla_hours]).to eq(24)
    expect(data[:order_sla_hours]).to eq(24)
    expect(data[:display_name]).to eq("Acme 店")
    expect(data[:enabled]).to eq(false)
    expect(data[:status]).to eq("active")
    expect(data[:source]).to eq("forum")
  end

  it "is enabled only when mc_enabled is set, the shop is active and there are no problems" do
    shop.custom_fields["mc_enabled"] = true
    shop.custom_fields["mc_sla_hours"] = 12
    shop.save_custom_fields
    data = described_class.for_group(shop.reload)
    expect(data[:enabled]).to eq(true)
    expect(data[:sla_hours]).to eq(12)
    expect(data[:order_sla_hours]).to eq(12)

    shop.custom_fields["mc_status"] = "disabled"
    shop.save_custom_fields
    expect(described_class.for_group(shop.reload)[:enabled]).to eq(false)
    expect(described_class.disabled?(shop)).to eq(true)
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

  it "reports owner_pending and a changed store slug as notices" do
    shop.custom_fields["mc_owner_pending"] = true
    shop.custom_fields["mc_wc_store_slug"] = "acme-new"
    shop.save_custom_fields
    expect(described_class.notices_for(shop.reload)).to contain_exactly(
      "owner_pending",
      "store_slug_changed",
    )
  end

  it "lists staff with roles for the bridge (no real-name field)" do
    data = described_class.for_bridge(shop)
    expect(data[:staff]).to contain_exactly({ username: owner.username, role: "owner" })
  end

  it "only allows forum-side settings to be edited through the group API" do
    editable = DiscoursePluginRegistry.editable_group_custom_fields.map(&:to_s)
    expect(editable).to include("mc_enabled", "mc_sla_hours")
    expect(editable).not_to include("mc_status", "mc_wp_store_id", "mc_source", "mc_owner_pending")
  end
end
