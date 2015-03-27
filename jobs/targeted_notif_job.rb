require 'resque'
require 'data_mapper'
require 'dm-mysql-adapter'

class TargetedNotification

  @queue = :targeted_background

  def self.perform(service_sid,json_message,offset=0,limit=100,params)
    target_devices = []
    target_devices = JSON.parse(params['target_devices']) rescue [] unless params['target_devices'].blank?
    gender = params['gender'].blank? ? "all" : params['gender']
    country = params['country']
    index = 0

  	start = Time.now
  	puts "==============================================================================="
    puts "Targeted PushNotification to : #{params.inspect}"
    puts "#{Time.now} start from #{offset} to #{(offset+ (limit-1))} : #{json_message}"
  	push_noti = PushNotification.new
    json_payload = JSON.parse(json_message).to_json

  	resque_log_json = {message: "start", sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, limit: limit, json_message: json_message}
	  Log.create(cat: "resque", body: resque_log_json, created: Time.now, err: false)
	
      if target_devices.size==0 && gender!='all'
        
         Registration.all(service_sid: service_sid, :country => country, :user => {:gender => gender}, :offset => offset, :limit => limit).each do |t|
               begin
                  push_noti.send(t.reg_id, json_payload) 
                  puts "#{Time.now}, serial: #{t.serial}, reg_id: #{t.reg_id}"
                  if index==0
  		              log_json = {reg_id: t.reg_id, sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message}
  		              Log.create(cat: "resque", body: log_json, created: Time.now, err: false)
  		            end
		              index = index + 1
               rescue => e
                  puts "ERROR : #{e.message}"
                  puts e.backtrace.join("\n\t")
                  log_json = {sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message, message: e.to_s, stacktrace:  e.backtrace.join("\n\t")}
                  Log.create(cat: "resque", body: log_json, created: Time.now, err: true)
               end
         end

      elsif target_devices.size>0 && gender=='all'
        
          Registration.all(service_sid: service_sid, :devices => {:model_name => target_devices}, :country => country, service_sid: service_sid, :offset => offset, :limit => limit).each do |t|
              begin
                  push_noti.send(t.reg_id, json_payload) 
                  puts "#{Time.now}, serial: #{t.serial}, reg_id: #{t.reg_id}"
                  if index==0
    		              log_json = {reg_id: t.reg_id, sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message}
    		              Log.create(cat: "resque", body: log_json, created: Time.now, err: false)
    		          end
    		          index = index + 1
               rescue => e
                  puts "ERROR : #{e.message}"
                  puts e.backtrace.join("\n\t")
                  log_json = {sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message, message: e.to_s, stacktrace:  e.backtrace.join("\n\t")}
                  Log.create(cat: "resque", body: log_json, created: Time.now, err: true)
               end
          end

      elsif target_devices.size>0 && gender!='all'
          
          Registration.all(service_sid: service_sid, :devices => {:model_name => target_devices}, :country => country, :user => {:gender => gender}, :offset => offset, :limit => limit).each do |t|
              begin
                  push_noti.send(t.reg_id, json_payload) 
                  puts "#{Time.now}, serial: #{t.serial}, reg_id: #{t.reg_id}"
                  if index==0
  		              log_json = {reg_id: t.reg_id, sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message}
  		              Log.create(cat: "resque", body: log_json, created: Time.now, err: false)
  		            end
		            index = index + 1
               rescue => e
                  puts "ERROR : #{e.message}"
                  puts e.backtrace.join("\n\t")
                  log_json = {sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, to: offset+(limit-1), limit: limit, json_message: json_message, message: e.to_s, stacktrace:  e.backtrace.join("\n\t")}
                  Log.create(cat: "resque", body: log_json, created: Time.now, err: true)
               end
          end

      end

    resque_log_json = {message: "finish", total_sent: index, sid: service_sid, gender: gender, devices: target_devices, country: country, from: offset, limit: limit, json_message: json_message}
    Log.create(cat: "resque", body: resque_log_json, created: Time.now, err: false)

	finish = Time.now
	puts "-------------------------------------------------------------------------------"
	puts "Targeted Notif FINISH from #{offset} to #{(offset+ (limit-1))}, start at #{start}, finish at #{Time.now}"
    duration = (finish - start)
    puts "duration : #{duration} secs"
    puts "==============================================================================="
  end
end
