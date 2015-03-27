 namespace :registration do

  desc "Add sample registration id"
    task :add_sample_registration do |t, args|
        require 'data_mapper'
        require 'dm-mysql-adapter'
        require_relative 'models/init'
        s = Service.first(sid: "GL01")
        u = User.first('muvoddhxlx')
        (0..2000000).each do |n|
            reg_id = "sample-#{n}-#{Time.now.to_i.to_s}"
            puts "reg_id : #{reg_id}"
            Registration.create(reg_id: reg_id, service: s, user: u)
        end
    end

    desc "Clean double registration ids"
    task :clean_registrations do 
      DataMapper.logger.level = DataMapper::Logger::Levels[:debug]
      Registration.aggregate(:serial, :service_sid, :all.count).each do |r|
        #only query data with more than 1 reg id for same serial and country
          if r[2]>1
              total = r[2]
              puts "================================================"
              Registration.all(:serial => r[0], :service_sid => r[1], :order => [:id.asc]).each_with_index do |reg, index|
                  if index<(total-1)
                      #Delete the older registration id data, only keep the latest registration id for same serial
                      puts "Delete #{reg.id}"
                      reg.destroy
                  end
              end
          end
      end
    end

 
end