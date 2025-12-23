Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Projects (auto-provisioning)
      post 'projects/provision', to: 'projects#provision'
      get 'projects/lookup', to: 'projects#lookup'

      # Traces
      post 'traces', to: 'traces#create'
      post 'traces/batch', to: 'traces#batch'
      get 'traces', to: 'traces#index'
      get 'traces/:id', to: 'traces#show'

      # Spans (for adding to existing trace)
      post 'traces/:trace_id/spans', to: 'spans#create'

      # Metrics
      post 'metrics', to: 'metrics#create'
      post 'metrics/batch', to: 'metrics#batch'
      get 'metrics', to: 'metrics#index'
      get 'metrics/:name/stats', to: 'metrics#stats'

      # Overview
      get 'overview', to: 'metrics#overview'
    end
  end

  # MCP Server
  namespace :mcp do
    get 'tools', to: 'tools#index'
    post 'tools/:name', to: 'tools#call'
    post 'rpc', to: 'tools#rpc'
  end

  # SSO from Platform
  get 'sso/callback', to: 'sso#callback'

  # Dashboard
  namespace :dashboard do
    root to: 'projects#index'

    resources :projects, only: [:index, :new, :create] do
      member do
        get 'overview'
        get 'requests'
        get 'jobs'
        get 'endpoints'
        get 'queries'
        get 'metrics'
      end
    end

    get 'overview', to: 'overview#show'

    resources :requests, only: [:index, :show]
    resources :traces, only: [:index, :show]
    resources :jobs, only: [:index]
    resources :queries, only: [:index, :show]
    resources :metrics, only: [:index, :show]
    resources :endpoints, only: [:index, :show]

    # Alerting
    resources :alerts, only: [:index, :show]
    resources :alert_rules, except: [:edit]
    resources :notification_channels, except: [:edit]

    # Dev Tools (development only)
    resource :dev_tools, only: [:show], controller: 'dev_tools' do
      post 'clean_traces'
      post 'clean_all'
    end
  end

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # WebSocket
  mount ActionCable.server => '/cable'

  root 'dashboard/projects#index'
end
