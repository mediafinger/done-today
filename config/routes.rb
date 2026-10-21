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
      # for the MCP server, revoke_all also takes the connected apps along
      resources :access_tokens, only: %i[ index create destroy ] do
        delete :destroy_all, on: :collection
      end
      resource :display_mode, only: %i[ update ]
      resource :time_zone, only: %i[ update ]
    end
  end

  # the MCP server for AI clients, a bearer token instead of the session (#108)
  match "mcp", to: "mcp/server#handle", via: %i[ get post delete ], as: :mcp

  # OAuth for hosted AI apps (#109): the discovery documents, and Doorkeeper at /oauth
  scope ".well-known", module: :oauth do
    get "oauth-protected-resource/mcp", to: "metadata#protected_resource", as: :oauth_protected_resource_metadata
    get "oauth-authorization-server", to: "metadata#authorization_server", as: :oauth_authorization_server_metadata
  end
  use_doorkeeper do
    controllers authorizations: "oauth/authorizations"
    skip_controllers :applications, :authorized_applications, :token_info
  end
  # RFC 7591, apps register themselves
  post "oauth/register", to: "oauth/registrations#create", as: :oauth_registration

  # the user's settings, /:org_slug/settings adds those of an org
  get "settings", to: "orgs/settings#show"

  # Org and project live in the path: /acme, /acme/members, /acme/website/days/2026-10-15.
  #   Reserved words are never an org (Sluggable::RESERVED_SLUGS), so routes
  #   added further down are not swallowed.
  #
  scope ":org_slug", module: :orgs, constraints: ->(request) { !Sluggable.reserved?(request.path_parameters[:org_slug]) } do
    get "/", to: "projects#index", as: :org
    get "settings", to: "settings#show", as: :org_settings
    # every project's tag times, `tags` is never a project (Sluggable::RESERVED_SLUGS)
    get "tags", to: "tag_times#index", as: :org_tags

    resources :members, only: %i[ index update ] do
      patch :deactivate, on: :member
      patch :reactivate, on: :member
    end

    resources :invitations, only: %i[ create destroy ] do
      patch :resend, on: :member
    end

    resources :projects, only: %i[ new create ]

    # the org-level paths above are never a project (Sluggable::RESERVED_SLUGS)
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
      resources :participation_requests, only: %i[ create ] do
        patch :grant, on: :member
        patch :decline, on: :member
      end
      resources :tags, param: :tag, only: %i[ index show ]
      resources :weeks, param: :week, only: %i[ show ]

      resources :members, only: [] do
        resources :entries, only: %i[ index ], controller: "member_entries"
      end
    end
  end

  # only admins are routed here, everyone else ends in the catch-all below (AdminConstraint)
  namespace :admin, module: "admins", constraints: ->(request) { AdminConstraint.matches?(request) } do
    get "", to: "pages#show", as: "home"

    # inherits from AdminController, see config/initializers/mission_control.rb
    mount MissionControl::Jobs::Engine, at: "/mission_control_jobs"
  end

  # development only, letter_opener_web is in the development group of the Gemfile
  namespace :dev, module: "devs", constraints: ->(request) { DevConstraint.matches?(request) } do
    get "", to: "pages#show", as: "home"
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)
  end

  # keep this at the bottom of the routes file
  # catch all unknown routes to NOT throw a FATAL ActionController::RoutingError
  match "*path", to: "application#error_404", via: :all,
    constraints: ->(request) { !request.path_parameters[:path].start_with?("rails/") }
end
