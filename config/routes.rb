Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "application#home"

  resource :session

  resources :passwords, param: :token

  scope module: :orgs, path: "/" do
    # get "/",                  to: "orgs#show",   as: "home"
  end

  # namespace :admin do
  #   mount MissionControl::Jobs::Engine, at: "/jobs"
  # end

  # keep this at the bottom of the routes file
  # catch all unknown routes to NOT throw a FATAL ActionController::RoutingError
  match "*path", to: "application#error_404", via: :all,
    constraints: ->(request) { !request.path_parameters[:path].start_with?("rails/") }
end
