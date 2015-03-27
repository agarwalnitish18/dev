# encoding: utf-8

class SamsungExtendedProfileApp < Sinatra::Base
  configure :production do
    enable :logging
    set :dump_errors => true
  end

  configure :development do
    enable :logging
    set :dump_errors => true
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end

require_relative 'configs/init'
require_relative 'helpers/init'
require_relative 'models/init'
require_relative 'routes/init'
require_relative 'jobs/init'
