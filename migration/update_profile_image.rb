require 'dm-migrations/migration_runner'
  
DataMapper::Logger.new(STDOUT, :debug)
DataMapper.logger.debug("Starting Update Profile Image URL")
  
User.all(:bucket => nil, :fields => [:uid,:photo_url]).each do |u|
          puts u.photo_url
          #split the bucket name
          photos = u.photo_url.split("/")
          bucket_name = photos[3]
          filename = photos[4]
          puts "bucket name : #{bucket_name}"
          puts "file name : #{filename}"
          User.first(uid: u.uid).update(bucket: bucket_name, photo_key: filename)
end
  
  
DataMapper.logger.debug("Completed Update Profile Image URL")
