require 'dm-migrations/migration_runner'
  
DataMapper::Logger.new(STDOUT, :debug)
DataMapper.logger.debug("Starting To Move Join Date")
  
service = Service.get('GL01')  
User.all.each do |u|
          service_user = ServiceUser.first_or_create( { :user => u, :service => service }, {
                :joined_at => u.gl_join_date,
                :last_accessed_at => u.last_access_date })
          u.service_users << service_user            
          u.save
          puts "#{service_user.inspect}"
end

DataMapper.logger.debug("Completed Move Join Date")
