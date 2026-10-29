# frozen_string_literal: true

# name: discourse-cyberforums-marketplace
# about: Cyberforums 商城：以文派集市（WooCommerce + MarketKing）为准镜像店铺组（签名 webhook 接收）、店铺资料字段、给聊天中转服务的只读店铺清单、评论访客账号接口、每店超时提醒与会话闲置定时任务
# version: 0.3.5
# authors: 白泽 (wenpai)
# url: https://feicode.com/FeiCode/discourse-cyberforums-marketplace
# required_version: 3.4.0

enabled_site_setting :cyberforums_marketplace_enabled

module ::CyberforumsMarketplace
  PLUGIN_NAME = "discourse-cyberforums-marketplace"
end

require_relative "lib/cyberforums_marketplace/engine"

# Must be top-level (not inside after_initialize) or stylesheet never ships.
register_asset "stylesheets/cyberforums-commerce-pm-sidebar.scss"

after_initialize do
  require_relative "lib/cyberforums_marketplace/shop_group"
  require_relative "lib/cyberforums_marketplace/vendor_fields"
  require_relative "lib/cyberforums_marketplace/woo_sync"
  require_relative "lib/cyberforums_marketplace/guest_users"
  require_relative "lib/cyberforums_marketplace/shop_threads"
  require_relative "app/jobs/scheduled/cyberforums_marketplace_sla_reminders"
  require_relative "app/jobs/scheduled/cyberforums_marketplace_stale_threads"
  require_relative "app/controllers/cyberforums_marketplace/vendors_controller"
  require_relative "app/controllers/cyberforums_marketplace/guests_controller"
  require_relative "app/controllers/cyberforums_marketplace/woo_webhooks_controller"
  require_relative "app/controllers/cyberforums_marketplace/commerce_controller"  # C4 PM commerce sidebar proxy

  CyberforumsMarketplace::VendorFields::TYPES.each do |name, type|
    register_group_custom_field_type(name, type)
  end
  # Only forum-side service settings are editable; WooCommerce-synced fields are not.
  CyberforumsMarketplace::VendorFields::ADMIN_EDITABLE.each do |name|
    register_editable_group_custom_field(name.to_sym)
  end

  on(:post_created) do |post, _opts, _user|
    CyberforumsMarketplace::ShopThreads.on_post_created(post)
  end

  # Shop metadata: visible to staff and to the shop's own members only.
  add_to_serializer(
    :basic_group,
    :cyberforums_vendor,
    include_condition: -> do
      SiteSetting.cyberforums_marketplace_enabled &&
        CyberforumsMarketplace::ShopGroup.shop_group?(object) &&
        (scope.is_staff? || (scope.user && object.users.exists?(id: scope.user.id)))
    end,
  ) { CyberforumsMarketplace::VendorFields.for_group(object) }
end
