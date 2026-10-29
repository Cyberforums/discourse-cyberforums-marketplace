# frozen_string_literal: true

module ::CyberforumsMarketplace
  # C4: Discourse-native PM sidebar. Viewer must already see the PM; then proxy
  # to marketplace-chat with flush token (server-side only).
  class CommerceController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    def topic_context
      raise Discourse::NotFound unless SiteSetting.cyberforums_marketplace_enabled
      raise Discourse::NotFound unless SiteSetting.cyberforums_marketplace_pm_commerce_sidebar_enabled

      topic = Topic.find_by(id: params[:topic_id].to_i)
      raise Discourse::NotFound if topic.nil? || !topic.private_message?
      raise Discourse::InvalidAccess unless Guardian.new(current_user).can_see?(topic)
      raise Discourse::NotFound unless ShopThreads.shop_pm?(topic)

      api_base = SiteSetting.cyberforums_marketplace_chat_api_base.to_s.strip.presence ||
        "https://chat.cyberforums.com"
      token = SiteSetting.cyberforums_marketplace_chat_proxy_token.to_s.strip
      raise Discourse::NotFound if token.blank?

      uri = URI.join(api_base.end_with?("/") ? api_base : api_base + "/", "v1/topics/#{topic.id}/commerce-context")
      req = Net::HTTP::Get.new(uri)
      req["x-mc-flush-token"] = token
      req["x-mc-viewer-username"] = current_user.username.to_s
      req["Accept"] = "application/json"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 3
      http.read_timeout = 5
      res = http.request(req)
      if res.code.to_i == 404
        render json: { ok: false, code: "thread_not_found" }, status: 404
        return
      end
      unless res.is_a?(Net::HTTPSuccess)
        render json: { ok: false, code: "upstream_error", status: res.code.to_i }, status: 502
        return
      end

      render json: JSON.parse(res.body)
    rescue JSON::ParserError
      render json: { ok: false, code: "upstream_bad_json" }, status: 502
    end
  end
end
