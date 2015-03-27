require 'resque'
require 'data_mapper'
require 'dm-mysql-adapter'
require 'aws-sdk'

class Notification

  @queue = :background

  def self.perform(service_sid,json_message,offset=0,limit=100,country_code='MYS')

  	start = Time.now
  	puts "==============================================================================="
    puts "PushNotification to country: #{country_code}"
    puts "#{Time.now} start from #{offset} to #{(offset+ (limit-1))} : #{json_message}"
  	push_noti = PushNotification.new
    index = 0
   
      Registration.all(service_sid: service_sid, :offset => offset, :country => country_code, :limit => limit, :fields => [:serial, :reg_id]).each do |t|
        begin
          json_payload = JSON.parse(json_message).to_json
  		    push_noti.send(t.reg_id, json_payload) 
          puts "#{Time.now}, serial: #{t.serial}, reg_id: #{t.reg_id}, country: #{country_code}"
          if index==0
              log_json = {sid: service_sid, country: country_code, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message}
              Log.create(cat: "resque", body: log_json, created: Time.now, err: false)
          end
          index = index + 1
        rescue => e
          puts "ERROR : #{e.message}"
          puts e.backtrace.join("\n\t")
          log_json = {sid: service_sid, country: country_code, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message, message: e.to_s, stacktrace:  e.backtrace.join("\n\t")}
          Log.create(cat: "resque", body: log_json, created: Time.now, err: true)
        end
	    end
	  
	finish = Time.now
	puts "-------------------------------------------------------------------------------"
	puts "FINISH from #{offset} to #{(offset+ (limit-1))}, start at #{start}, finish at #{Time.now}"
    duration = (finish - start)
    puts "duration : #{duration} secs"
    puts "==============================================================================="
  end
end
