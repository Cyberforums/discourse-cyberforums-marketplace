# frozen_string_literal: true

module ::CyberforumsMarketplace
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace CyberforumsMarketplace
  end
end

CyberforumsMarketplace::Engine.routes.draw do
  get "/vendors" => "vendors#index", :defaults => { format: :json }
  post "/guests" => "guests#ensure", :defaults => { format: :json }
end
