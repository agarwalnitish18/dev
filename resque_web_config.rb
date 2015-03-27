require 'bundler/setup'
require 'json'
require 'dotenv'

Bundler.require(:default)

Dotenv.load

redis_host = ENV['REDIS_HOST'] || 'localhost'
redis_port = ENV['REDIS_PORT'] || 6379

puts "REDIS PORT: #{redis_port}"
Resque.redis = Redis.new(:host => redis_host, :port => redis_port)