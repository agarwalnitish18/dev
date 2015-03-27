# encoding: utf-8
db = ENV['DATABASE_URL']
unless db
  $stderr.puts "Error: missing DATABASE_URL."
  exit 1
end

#DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, db)
DataMapper::Property::String.length(200)

require_relative 'api_key'
require_relative 'user'
require_relative 'device'
require_relative 'device_category'
require_relative 'registration'
require_relative 'log'

DataMapper.finalize