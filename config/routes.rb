Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "application#home"

  get "impressum", to: "legal#imprint", as: :imprint
  get "datenschutz", to: "legal#privacy", as: :privacy
  get "help", to: "help#show"

  # As neiter the 'users' nor the 'orgs' module are namespaced,
  #   pathes and 'as: :names' in them have to be uniquely named.
  #   e.g. you can not define get "/settings" in both modules and expect it to work.
  #
  scope module: :users, path: "/" do
    resource :session, only: %i[ new create destroy ]
    resources :passwords, param: :token, only: %i[ new create edit update ]
    # the emailed invitation link, owners send it from /:org/members
    resources :invitations, param: :token, only: %i[ show update ], as: :accept_invitations

    resource :user, only: %i[ edit update ] do
      resource :email, only: %i[ edit update destroy ], controller: "user_emails" do
        # the links mailed to the new and to the old address, they work without a session
        resources :confirmations, param: :token, only: %i[ show update ], controller: "user_email_confirmations"
        resources :reverts, param: :token, only: %i[ show update ], controller: "user_email_reverts"
      end
      resource :password, only: %i[ edit update ], controller: "user_passwords"
      resources :sessions, only: %i[ index destroy ], controller: "user_sessions" do
        delete :destroy_others, on: :collection
      end
      resource :display_mode, only: %i[ update ]
      resource :time_zone, only: %i[ update ]
    end
  end

  # the user's settings, /:org_slug/settings adds those of an org
  get "settings", to: "orgs/settings#show"

  # Org and project live in the path: /acme, /acme/members, /acme/website/days/2026-10-15.
  #   Words a top-level path uses are never an org (Org::RESERVED_SLUGS), so routes
  #   added further down are not swallowed.
  #
  scope ":org_slug", module: :orgs, constraints: ->(request) { Org::RESERVED_SLUGS.exclude?(request.path_parameters[:org_slug]) } do
    get "/", to: "projects#index", as: :org
    get "settings", to: "settings#show", as: :org_settings

    resources :members, only: %i[ index update ] do
      patch :deactivate, on: :member
      patch :reactivate, on: :member
    end

    resources :invitations, only: %i[ create destroy ] do
      patch :resend, on: :member
    end

    resources :projects, only: %i[ new create ]

    # the org-level paths above are never a project (Project::RESERVED_SLUGS)
    scope ":project_slug" do
      get "/", to: "projects#show", as: :project
      patch "/", to: "projects#update", as: nil
      get "edit", to: "projects#edit", as: :edit_project
      patch "archive", to: "projects#archive", as: :archive_project
      patch "unarchive", to: "projects#unarchive", as: :unarchive_project
      get "validate_times", to: "projects#validate_times", as: :validate_times_project
      get "export_csv", to: "projects#export_csv", as: :export_csv_project
      get "export_days_csv", to: "projects#export_days_csv", as: :export_days_csv_project

      resources :days, param: :date, only: %i[ show edit ], constraints: { date: /\d{4}-\d{2}-\d{2}/ }
      resources :entries, only: %i[ create update ] do
        resource :history, only: %i[ show ], controller: "entry_histories"
      end
      resources :participants, only: %i[ create update destroy ]
      resources :guest_invitations, only: %i[ create destroy ] do
        patch :resend, on: :member
      end
      # members who do not take part ask to join, those who manage the project decide
      resources :access_requests, only: %i[ create ] do
        patch :grant, on: :member
        patch :decline, on: :member
      end
      resources :tags, param: :tag, only: %i[ show ]
      resources :weeks, param: :week, only: %i[ show ]

      resources :members, only: [] do
        resources :entries, only: %i[ index ], controller: "member_entries"
      end
    end
  end

  # namespace :admin do
  #   mount MissionControl::Jobs::Engine, at: "/jobs"
  # end

  # keep this at the bottom of the routes file
  # catch all unknown routes to NOT throw a FATAL ActionController::RoutingError
  match "*path", to: "application#error_404", via: :all,
    constraints: ->(request) { !request.path_parameters[:path].start_with?("rails/") }
end
