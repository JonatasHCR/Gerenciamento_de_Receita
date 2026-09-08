source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

# Auth
gem "devise"
# SSO via Keycloak. O :database_authenticatable saiu do User, entao nao ha mais
# senha local para hashear — a devise-argon2 foi junto.
gem "omniauth_openid_connect"
# Exige que o inicio do fluxo OmniAuth seja um POST com token CSRF. Sem ela o
# OmniAuth 2 recusa o GET /users/auth/keycloak e o login nao comeca.
gem "omniauth-rails_csrf_protection"
gem "pundit"

# Audit trail
gem "paper_trail"

# Dashboard / charts
gem "chartkick"
gem "groupdate"

# Pagination
gem "pagy"

# Excel import / export
gem "roo"
gem "roo-xls"
gem "caxlsx"

# PDF export (relatórios)
gem "prawn"
gem "prawn-table"

# Tailwind CSS
gem "tailwindcss-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  # TDD
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
end

group :development do
  gem "web-console"
  gem "foreman"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "simplecov", require: false
  gem "pundit-matchers"
end
