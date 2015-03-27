# encoding: utf-8

if ENV['RACK_ENV'] == "test" # hack to simulate require_once

  require 'bundler/setup'
  require 'json'
  require 'dotenv'

  ENV['RACK_ENV'] = "test"
  ENV['DATABASE_URL'] = "mysql://samsung_eps:samsung_eps@localhost/samsung_eps"


  Bundler.require(:default, ENV['RACK_ENV'].to_sym)
  require_relative '../server.rb'


  puts "Initializing database..."
  require_relative '../models/init.rb'
  #DataMapper.setup(:default, :adapter => 'in_memory')
  

  require 'rack/test'
  RSpec.configure do |conf|
    conf.include Rack::Test::Methods
  end


  Dotenv.load

  redis_host = ENV['REDIS_HOST'] || 'localhost'
  redis_port = ENV['REDIS_PORT'] || 6379
  Resque.redis = Redis.new(:host => redis_host, :port => redis_port)

end
