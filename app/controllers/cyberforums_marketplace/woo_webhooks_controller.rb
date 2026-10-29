# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Receives merchant snapshots from WooCommerce (native webhook, custom topic
  # marketking_vendor.updated). Only HMAC-SHA256 signed bodies are accepted
  # (X-WC-Webhook-Signature, base64). Off by default.
  class WooWebhooksController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :verify_authenticity_token,
                       :check_xhr,
                       :redirect_to_login_if_required,
                       :preload_json,
                       raise: false

    def vendor
      raise Discourse::NotFound unless SiteSetting.cyberforums_marketplace_woo_webhook_enabled
      secret = SiteSetting.cyberforums_marketplace_woo_webhook_secret.to_s
      raise Discourse::NotFound if secret.empty?

      raw = request.raw_post.to_s
      signature = request.headers["X-WC-Webhook-Signature"].to_s

      # Unsigned ping sent by WooCommerce when the webhook is saved: acknowledge, do nothing.
      return render(json: { ok: true, ping: true }) if signature.empty? && WooSync.ping?(raw)

      unless WooSync.valid_signature?(raw, signature, secret)
        return render(json: { error: "bad_signature" }, status: :unauthorized)
      end

      expected_source = SiteSetting.cyberforums_marketplace_woo_webhook_source.to_s.strip
      if expected_source.present?
        source = request.headers["X-WC-Webhook-Source"].to_s.strip
        if source.chomp("/") != expected_source.chomp("/")
          return render(json: { error: "bad_source" }, status: :unauthorized)
        end
      end

      topic = request.headers["X-WC-Webhook-Topic"].to_s
      if topic.present? && topic != WooSync::TOPIC
        return render(json: { ok: true, result: "ignored", reason: "topic" })
      end

      payload =
        begin
          JSON.parse(raw)
        rescue JSON::ParserError
          return render(json: { error: "invalid_json" }, status: :unprocessable_entity)
        end

      render json: { ok: true }.merge(WooSync.apply!(payload))
    rescue WooSync::Invalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
