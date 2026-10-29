# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Staged guest users for product-comments (admin API key only, off by default).
  class GuestsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def ensure
      raise Discourse::NotFound unless SiteSetting.cyberforums_marketplace_guest_api_enabled
      params.require(:email)
      params.require(:username)
      render json:
               GuestUsers.ensure!(
                 email: params[:email],
                 name: params[:name],
                 preferred_username: params[:username],
                 website: params[:website],
                 avatar_url: params[:avatar_url],
               )
    rescue GuestUsers::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
