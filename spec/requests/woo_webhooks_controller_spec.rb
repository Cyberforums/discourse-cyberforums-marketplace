# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::WooWebhooksController do
  fab!(:merchant) { Fabricate(:user, email: "boss@example.com") }

  let(:secret) { "test-secret-#{SecureRandom.hex(4)}" }
  let(:body) do
    {
      schema: CyberforumsMarketplace::WooSync::SCHEMA,
      event: "vendor.updated",
      reason: "meta_changed",
      generated_at: Time.utc(2026, 10, 29).iso8601,
      site_url: "https://market.test/",
      vendor: {
        wp_user_id: 7,
        email: "boss@example.com",
        approved: true,
        is_vendor: true,
        store_name: "Acme",
        store_slug: "acme",
      },
    }.to_json
  end

  def sign(raw, key = secret)
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, raw))
  end

  def deliver(raw, headers = {})
    post "/marketplace/woo/vendor",
         params: raw,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "X-WC-Webhook-Topic" => "marketking_vendor.updated",
           "X-WC-Webhook-Source" => "https://market.test/",
         }.merge(headers)
  end

  before do
    SiteSetting.cyberforums_marketplace_enabled = true
    SiteSetting.cyberforums_marketplace_woo_webhook_enabled = true
    SiteSetting.cyberforums_marketplace_woo_webhook_secret = secret
  end

  it "applies a correctly signed delivery" do
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(200)
    expect(response.parsed_body).to include(
      "ok" => true,
      "result" => "applied",
      "group" => "shop-acme",
    )
    expect(Group.find_by(name: "shop-acme").users).to include(merchant)
  end

  it "works without a session or CSRF token even when login is required" do
    SiteSetting.login_required = true
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(200)
  end

  it "rejects a missing or wrong signature" do
    deliver(body)
    expect(response.status).to eq(401)
    deliver(body, "X-WC-Webhook-Signature" => sign(body, "wrong"))
    expect(response.status).to eq(401)
    expect(Group.find_by(name: "shop-acme")).to be_nil
  end

  it "rejects a tampered body" do
    sig = sign(body)
    deliver(body.sub("acme", "evil"), "X-WC-Webhook-Signature" => sig)
    expect(response.status).to eq(401)
  end

  it "acknowledges the unsigned WooCommerce ping without doing anything" do
    post "/marketplace/woo/vendor",
         params: "webhook_id=12",
         headers: {
           "CONTENT_TYPE" => "application/x-www-form-urlencoded",
         }
    expect(response.status).to eq(200)
    expect(response.parsed_body["ping"]).to eq(true)
  end

  it "is not found when switched off or when no secret is configured" do
    SiteSetting.cyberforums_marketplace_woo_webhook_enabled = false
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(404)

    SiteSetting.cyberforums_marketplace_woo_webhook_enabled = true
    SiteSetting.cyberforums_marketplace_woo_webhook_secret = ""
    deliver(body, "X-WC-Webhook-Signature" => sign(body, ""))
    expect(response.status).to eq(404)

    SiteSetting.cyberforums_marketplace_woo_webhook_secret = secret
    SiteSetting.cyberforums_marketplace_enabled = false
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(404)
  end

  it "checks the source site when configured" do
    SiteSetting.cyberforums_marketplace_woo_webhook_source = "https://other.test"
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(401)
    SiteSetting.cyberforums_marketplace_woo_webhook_source = "https://market.test"
    deliver(body, "X-WC-Webhook-Signature" => sign(body))
    expect(response.status).to eq(200)
  end

  it "ignores other topics" do
    deliver(body, "X-WC-Webhook-Signature" => sign(body), "X-WC-Webhook-Topic" => "order.created")
    expect(response.status).to eq(200)
    expect(response.parsed_body["result"]).to eq("ignored")
    expect(Group.find_by(name: "shop-acme")).to be_nil
  end

  it "returns 422 for signed but invalid payloads" do
    raw = "not json"
    # Rails itself rejects malformed JSON sent as application/json (400) before the action runs.
    deliver(raw, "X-WC-Webhook-Signature" => sign(raw))
    expect(response.status).to eq(400)
    deliver(raw, "X-WC-Webhook-Signature" => sign(raw), "CONTENT_TYPE" => "text/plain")
    expect(response.status).to eq(422)
    raw = { schema: "other" }.to_json
    deliver(raw, "X-WC-Webhook-Signature" => sign(raw))
    expect(response.status).to eq(422)
  end
end
