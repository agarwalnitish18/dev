require 'bundler/setup'
require 'json'
Bundler.require(:default)
Dotenv.load

root = ::File.dirname(__FILE__)
require ::File.join( root, 'server' )
require 'resque/tasks'

Dir.glob('libs/tasks/*.rake').each { |r| load r}


namespace :eps do 

  task :syncdb do 
    DataMapper.auto_upgrade!
  end
  
end
