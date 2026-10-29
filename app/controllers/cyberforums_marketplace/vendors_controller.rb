# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Read-only shop list for the marketplace-chat bridge (admin API key only).
  # Disabled shops are hidden unless include_disabled=1.
  class VendorsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def index
      include_disabled = %w[1 true].include?(params[:include_disabled].to_s)
      vendors =
        ShopGroup
          .shop_groups
          .includes(:_custom_fields)
          .reject { |g| !include_disabled && VendorFields.disabled?(g) }
          .map { |g| VendorFields.for_bridge(g) }
      render json: { prefix: ShopGroup.prefix, woo: WooSync.status, vendors: vendors }
    end
  end
end
