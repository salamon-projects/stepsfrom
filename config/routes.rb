Rails.application.routes.draw do
  root "home#index"

  get "search", to: "search#show", as: :search
  resources :destinations, only: :show
  resources :properties, only: :show

  # Outbound click to a booking site; logged, then redirected.
  get "go/:listing_id", to: "outbound#show", as: :outbound

  get "how-we-verify", to: "pages#how_we_verify", as: :how_we_verify
  get "affiliate-disclosure", to: "pages#affiliate_disclosure", as: :affiliate_disclosure
  get "privacy", to: "pages#privacy", as: :privacy
  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }
  get "robots.txt", to: "pages#robots", as: :robots, defaults: { format: :text }

  namespace :admin do
    root "properties#index"
    resources :destinations, except: :show do
      post :import, on: :member
    end
    resources :properties do
      member do
        post :approve
        post :reject
        post :reclassify
      end
      resources :listings, except: %i[index show]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
