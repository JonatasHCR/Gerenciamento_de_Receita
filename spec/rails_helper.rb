require 'spec_helper'
ENV['RAILS_ENV'] = 'test'

# Cobertura de testes (SimpleCov) — precisa iniciar antes de carregar o app.
require 'simplecov'
SimpleCov.start 'rails' do
  enable_coverage :branch
  add_filter %w[/spec/ /config/ /db/ /vendor/]
  add_group "Services",    "app/services"
  add_group "Policies",    "app/policies"
end

require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'pundit/matchers'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Pundit::Matchers, type: :policy
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
