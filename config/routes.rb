Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "application#home"

  # As neiter the 'users' nor the 'orgs' module are namespaced,
  #   pathes and 'as: :names' in them have to be uniquely named.
  #   e.g. you can not define get "/settings" in both modules and expect it to work.
  #
  scope module: :users, path: "/" do
    resource :session, only: %i[ new create destroy ]
    resources :passwords, param: :token, only: %i[ new create edit update ]

    get "/preferences", to: "preferences#show"

    patch "dark_mode", to: "display_modes#dark"
    patch "light_mode", to: "display_modes#light"
    patch "system_mode", to: "display_modes#system"
  end

  # resources :switch_current_organizations, only: %i[index show create destroy]
  get "open/:slug_org(/:slug_project)", to: "switch_orgs#switch_to", as: :open

  scope module: :orgs, path: "/" do
    # resources :days, only: %i[ index show ] # TODO: ensure these are unused now
    resources :entries, only: %i[ index create update ]
    resources :projects, param: :slug, only: %i[ index show ]

    get "settings", to: "settings#show"
  end

  # namespace :admin do
  #   mount MissionControl::Jobs::Engine, at: "/jobs"
  # end

  # keep this at the bottom of the routes file
  # catch all unknown routes to NOT throw a FATAL ActionController::RoutingError
  match "*path", to: "application#error_404", via: :all,
    constraints: ->(request) { !request.path_parameters[:path].start_with?("rails/") }
end
