# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'email_spec'
require 'capybara/poltergeist'
require "rack_session_access/capybara"

#require 'webmock/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  #config.order = "random"

  Capybara.javascript_driver = :poltergeist
  Capybara.ignore_hidden_elements = true
  Capybara.default_wait_time = 5

  DatabaseCleaner.strategy = :truncation
  DatabaseCleaner.orm = "mongoid"

  config.before(:suite) do
    Tripod.cache_store.clear!
    
    #delete everything from fuseki
    Tripod::SparqlClient::Update.update('
      # delete from default graph:
      DELETE {?s ?p ?o} WHERE {?s ?p ?o};
      # delete from named graphs:
      DELETE {graph ?g {?s ?p ?o}} WHERE {graph ?g {?s ?p ?o}};
    ')

    # seed everything.
    puts 'seeding'
    load "#{Rails.root}/db/seeds.rb"

  end

  config.before(:each) do

    # delete anything from our 'data graph'
    Tripod::SparqlClient::Update.update("
      DELETE {graph <#{Digitalsocial::DATA_GRAPH}> {?s ?p ?o}} WHERE {graph <#{Digitalsocial::DATA_GRAPH}> {?s ?p ?o}};
    ")

    # delete triples for narrower (for broad-narrow relations).
    # when we set a narrow concept (we also add a triple to the top concept).
    Tripod::SparqlClient::Update.update("
      DELETE {
        graph ?g {
          ?s <#{RDF::SKOS.narrower}> ?o .
        }
      }
      WHERE {
        graph ?g {
          ?s <#{RDF::SKOS.narrower}> ?o .
        }
      };
    ")

    # delete non top concepts. These will have a broader triple.
    Tripod::SparqlClient::Update.update("
      DELETE {
        graph ?g {
          ?s ?p ?o .
        }
      }
      WHERE {
        graph ?g {
          ?s ?p ?o .
          ?s <#{RDF::SKOS.broader}> ?o .
        }
      };
    ")

    # clean mongo
    DatabaseCleaner.clean

    Tripod.cache_store.clear!

  end

  config.include Warden::Test::Helpers, type: :feature

  config.before :all, type: :feature do
    Warden.test_mode!
  end
  config.after :all, type: :feature do
    Warden.test_reset!
  end

  config.include(EmailSpec::Helpers)
  config.include(EmailSpec::Matchers)

end
