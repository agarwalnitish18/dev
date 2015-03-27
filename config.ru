require 'bundler/setup'
require 'json'
require 'dotenv'

Bundler.require(:default)

Dotenv.load

root = ::File.dirname(__FILE__)
require ::File.join( root, 'server' )

redis_host = ENV['REDIS_HOST'] || 'localhost'
redis_port = ENV['REDIS_PORT'] || 6379
Resque.redis = Redis.new(:host => redis_host, :port => redis_port)

run SamsungExtendedProfileApp.new
