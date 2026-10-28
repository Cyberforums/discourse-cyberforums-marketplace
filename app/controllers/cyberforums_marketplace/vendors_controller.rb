# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Read-only shop list for the marketplace-chat bridge (admin API key only).
  class VendorsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def index
      vendors = ShopGroup.shop_groups.includes(:_custom_fields).map { |g| VendorFields.for_bridge(g) }
      render json: {
               prefix: ShopGroup.prefix,
               verified_group: SiteSetting.cyberforums_marketplace_verified_group,
               verified_group_exists: ShopGroup.verified_group.present?,
               vendors: vendors,
             }
    end
  end
end
