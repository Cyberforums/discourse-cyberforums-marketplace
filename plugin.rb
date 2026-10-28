# frozen_string_literal: true

# name: discourse-cyberforums-marketplace
# about: Cyberforums 商城：店铺群组（shop-*）自动设置、灯鹿实名门槛、店铺资料字段、给聊天中转服务的只读店铺清单、评论访客账号接口
# version: 0.1.0
# authors: 白泽 (wenpai)
# url: https://feicode.com/FeiCode/discourse-cyberforums-marketplace
# required_version: 3.4.0

enabled_site_setting :cyberforums_marketplace_enabled

module ::CyberforumsMarketplace
  PLUGIN_NAME = "discourse-cyberforums-marketplace"
end

require_relative "lib/cyberforums_marketplace/engine"

after_initialize do
  require_relative "lib/cyberforums_marketplace/vendor_fields"
  require_relative "lib/cyberforums_marketplace/shop_group"
  require_relative "lib/cyberforums_marketplace/guest_users"
  require_relative "app/controllers/cyberforums_marketplace/vendors_controller"
  require_relative "app/controllers/cyberforums_marketplace/guests_controller"

  CyberforumsMarketplace::VendorFields::TYPES.each do |name, type|
    register_group_custom_field_type(name, type)
    register_editable_group_custom_field(name.to_sym)
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

  on(:group_created) do |group|
    next unless SiteSetting.cyberforums_marketplace_enabled
    CyberforumsMarketplace::ShopGroup.apply_preset!(group) if CyberforumsMarketplace::ShopGroup.shop_group?(group)
  end

  on(:user_added_to_group) do |user, group, *_rest|
    next unless SiteSetting.cyberforums_marketplace_enabled
    CyberforumsMarketplace::ShopGroup.enforce_verified!(user, group)
  end

  on(:user_removed_from_group) do |user, group|
    next unless SiteSetting.cyberforums_marketplace_enabled
    CyberforumsMarketplace::ShopGroup.on_left_verified_group!(user, group)
  end

  Discourse::Application.routes.append do
    mount ::CyberforumsMarketplace::Engine, at: "/marketplace"
  end
end
