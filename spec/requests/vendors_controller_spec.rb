# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::VendorsController do
  fab!(:admin)
  fab!(:user)
  fab!(:shop) { Fabricate(:group, name: "shop-acme") }
  fab!(:closed) { Fabricate(:group, name: "shop-closed") }

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    closed.custom_fields["mc_status"] = "disabled"
    closed.save_custom_fields
  end

  it "denies anonymous and regular users" do
    get "/marketplace/vendors.json"
    expect(response.status).to eq(403).or eq(404)
    sign_in(user)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(403).or eq(404)
  end

  it "lists active shop groups for admins and hides disabled ones" do
    sign_in(admin)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(200)
    names = response.parsed_body["vendors"].map { |v| v["group_name"] }
    expect(names).to eq(["shop-acme"])
    expect(response.parsed_body["woo"]).to include("webhook_enabled" => false)
    expect(response.parsed_body).not_to have_key("verified_group")
  end

  it "shows disabled shops on request" do
    sign_in(admin)
    get "/marketplace/vendors.json", params: { include_disabled: 1 }
    rows = response.parsed_body["vendors"].index_by { |v| v["group_name"] }
    expect(rows.keys).to contain_exactly("shop-acme", "shop-closed")
    expect(rows["shop-closed"]["status"]).to eq("disabled")
  end

  it "is unavailable when the plugin is disabled" do
    SiteSetting.cyberforums_marketplace_enabled = false
    sign_in(admin)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(404)
  end
end
