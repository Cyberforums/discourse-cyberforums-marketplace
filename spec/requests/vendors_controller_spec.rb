# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::VendorsController do
  fab!(:admin)
  fab!(:user)
  fab!(:shop) { Fabricate(:group, name: "shop-acme") }

  before { SiteSetting.cyberforums_marketplace_enabled = true }

  it "denies anonymous and regular users" do
    get "/marketplace/vendors.json"
    expect(response.status).to eq(403).or eq(404)
    sign_in(user)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(403).or eq(404)
  end

  it "lists shop groups for admins" do
    sign_in(admin)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(200)
    names = response.parsed_body["vendors"].map { |v| v["group_name"] }
    expect(names).to eq(["shop-acme"])
  end

  it "is unavailable when the plugin is disabled" do
    SiteSetting.cyberforums_marketplace_enabled = false
    sign_in(admin)
    get "/marketplace/vendors.json"
    expect(response.status).to eq(404)
  end
end
