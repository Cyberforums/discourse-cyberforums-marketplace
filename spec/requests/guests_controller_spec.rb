# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::GuestsController do
  fab!(:admin)
  fab!(:member) { Fabricate(:user, name: "Real Name", email: "real@example.com") }

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    SiteSetting.cyberforums_marketplace_guest_api_enabled = true
    sign_in(admin)
  end

  it "creates a staged guest" do
    post "/marketplace/guests.json", params: { email: "Guest@Example.com", name: "小王", username: "xiaowang" }
    expect(response.status).to eq(200)
    u = User.find(response.parsed_body["id"])
    expect(u.staged).to eq(true)
    expect(u.email).to eq("guest@example.com")
  end

  it "is idempotent for the same email" do
    2.times { post "/marketplace/guests.json", params: { email: "g@example.com", name: "A", username: "ga" } }
    expect(UserEmail.where(email: "g@example.com").count).to eq(1)
  end

  it "never renames a real member" do
    post "/marketplace/guests.json", params: { email: "real@example.com", name: "Hacker", username: "x" }
    expect(response.status).to eq(200)
    expect(member.reload.name).to eq("Real Name")
    expect(response.parsed_body["staged"]).to eq(false)
  end

  it "is off unless enabled" do
    SiteSetting.cyberforums_marketplace_guest_api_enabled = false
    post "/marketplace/guests.json", params: { email: "g@example.com", username: "g" }
    expect(response.status).to eq(404)
  end

  it "rejects non-admins" do
    sign_in(Fabricate(:user))
    post "/marketplace/guests.json", params: { email: "g@example.com", username: "g" }
    expect(response.status).to eq(403).or eq(404)
  end
end
