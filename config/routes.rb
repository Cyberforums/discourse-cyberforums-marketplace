# frozen_string_literal: true

CyberforumsMarketplace::Engine.routes.draw do
  get "/vendors" => "vendors#index", :defaults => { format: :json }
  post "/guests" => "guests#ensure", :defaults => { format: :json }
  post "/woo/vendor" => "woo_webhooks#vendor", :defaults => { format: :json }
  get "/topics/:topic_id/commerce-context" => "commerce#topic_context", :defaults => { format: :json }
end

Discourse::Application.routes.draw { mount ::CyberforumsMarketplace::Engine, at: "/marketplace" }
