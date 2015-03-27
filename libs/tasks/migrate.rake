namespace :dm do

	desc "Clean-up datamapper migration garbages"
	task :cleanup do
		require 'data_mapper'
		require 'dm-mysql-adapter'
		require 'dm-migrations/migration_runner'

		require_relative '../../models/init'
		require_relative '../../models/cleanup'		

		migrate_up!
	end

    desc "Move existing GL01 joined date and last_accessed_date to service_users table"
    task :move_join_date do
        require 'data_mapper'
        require 'dm-mysql-adapter'
        require 'dm-migrations/migration_runner'
  
        require_relative '../../models/init'
        require_relative '../../migration/move_join_date'
    end

	desc "Update profile image url to only store the filename"
    task :update_profile_image do
   		require 'data_mapper'
        require 'dm-mysql-adapter'
        require 'dm-migrations/migration_runner'
  
        require_relative '../../models/init'
        require_relative '../../migration/update_profile_image'

        migrate_up!
    end

    desc "Create initial data for device categoy"
    task :initial_device_category do
   		require 'data_mapper'
        require 'dm-mysql-adapter'
        require 'dm-migrations/migration_runner'
  
        require_relative '../../models/init'
        require_relative '../../migration/initial_device_category'

        migrate_up!
    end


    desc "Add new service"
    task :add_service, [:sid, :service_name] do |t, args|
        require 'data_mapper'
        require 'dm-mysql-adapter'
  
        require_relative '../../models/init'
        puts "args: #{args}"
        Service.create(sid: args.sid, service_name: args.service_name)
    end

    desc "Update service with the keys"
    task :update_service_with_samsung_keys, [:sid, :client_id, :client_secret] do |t, args|
        require 'data_mapper'
        require 'dm-mysql-adapter'
  
        require_relative '../../models/init'

        puts "update service with samsung keys: #{args}"
        s = Service.first(sid: args.sid)
        s.update(client_id: args.client_id, client_secret: args.client_secret)
    end

    desc "Fix invalid eps device mac address"
    task :fix_mac_address do |t, args|
        require 'data_mapper'
        require 'dm-mysql-adapter'
  
        require_relative '../../models/init'
        counter = 0
        Device.all(:mac_address.like => '%3A%').each_with_index do |dev,index|
            unless dev.mac_address.index("%3A").nil?
                counter += 1
                puts "#{counter}. fix #{dev.mac_address}"
                dev.mac_address = dev.mac_address.gsub("%3A",":")
                dev.save
            end
        end
        puts "fix mac_address done"
    end

    desc "Fix devices"
    task :fix_devices do 
         require 'data_mapper'
         require 'dm-mysql-adapter'

         sql_count = "select count(serial) as total_duplicate from (select serial, user_uid, count(user_uid) as total_user from devices group by serial, user_uid) serial_user where total_user > 1";
         total_count = DataMapper.repository.adapter.select(sql_count)
         puts "Total duplicate user_uid count: #{total_count[0]}"

         sql = "select serial, user_uid from (select serial, user_uid, count(user_uid) as total_user from devices group by serial, user_uid) serial_user where total_user > 1";
         dataset = DataMapper.repository.adapter.select(sql)
         total_removed = 0
         dataset.each do |d|
            #puts "DEVICE: #{d.serial} : #{d.user_uid}"
            Device.all(serial: d.serial, user_uid: d.user_uid).each_with_index do |t, index|
                #puts "#{index} #{t.serial} : #{t.user_uid}"
                if index>0
                    t.destroy
                    puts "Removed id: #{t.id}"
                end
            end
        end

        check_unique_sql = "show index from devices where Key_name = 'unique_serial_user_uid'"
        unique_dataset = DataMapper.repository.adapter.select(check_unique_sql)
        #puts "unique_dataset : #{unique_dataset}"
        if unique_dataset.to_a.size == 0
            unique_sql = "ALTER TABLE `devices` ADD UNIQUE INDEX `unique_serial_user_uid` (`serial` ASC, `user_uid` ASC)"
            DataMapper.repository.adapter.execute(unique_sql)
            puts "Apply unique constraint for serial and user_uid"
        end
        
        puts "TOTAL removed duplicate rows: #{total_removed}" if total_removed > 0
    end

end