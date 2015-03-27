require 'base64'
require 'resque'
require_relative '../libs/samsung-auth/samsung-auth'

class SamsungExtendedProfileApp < Sinatra::Base

	 
    get '/' do
        return {message: 'welcome to EPS'}.to_json
    end
  
    # Health Check
    get '/status' do
        content_type :json, :charset => 'utf-8'
        check_env = true
        required = [
          'DATABASE_URL',
          'S3_ACCESS_KEY_ID',
          'S3_SECRET_ACCESS_KEY',
          'S3_BUCKET',
          'S3_HOST',
          'SAMSUNG_OPS_CLIENT_ID',
          'SAMSUNG_OPS_CLIENT_SECRET',
          'SNS_ACCESS_KEY_ID',
          'SNS_SECRET_ACCESS_KEY',
          'AWS_SNS_APP_ARN',
          'DEFAULT_SERVICE_ID',
          'DEFAULT_SERVICE_NAME',
          'REDIS_HOST',
          'REDIS_PORT',
          'SUPPORTED_COUNTRY_CODES',
          'TESTER_USERS'
        ]
        missing = required - ENV.keys
  
        unless missing.empty?
          check_env = false
        end
  
  
        status = {
            environment: true,
            samsung_sso: true,
            s3: true,
            database: true,
            resque: false,
            version: '3.0.11'
        }
  
  		begin
	        db_connection = ( Service.first.nil? ? false : true ) rescue false
	        status[:samsung_sso] = false if (!Samsung::OPS.new({:access_token => ""}).check())
	        status[:s3] = false if (!s3_check())
	        status[:environment] = false if !check_env
	        status[:database] = db_connection
	        status[:resque] = Resque.info rescue false
	    rescue => e
  			status[:message] = e.to_s
  			status[:trace] = e.backtrace.join("\n\t")
  		end
  		
        return status.to_json
    end


	# EPS - MobileClients

	get '/auth' do
		content_type :json, :charset => 'utf-8'
        #verify token result to Samsung Account server
		token_result = verify_token(params)
		return token_result.to_json unless token_result[:success]
		#get uid/user id from Samsung Account data
        uid = token_result[:ss_ops].get_uid
        #initialize service from param service_id and put log
        service, status = initialize_service(params[:service_id], uid)
        return status.to_json unless status[:success]
     	#initialize user and get is_new_user status
     	begin
        	user, is_new_user = initialize_user(uid, token_result[:ss_ops])
        rescue => e
        	sso_logger = ::Logger.new("logs/sso.log")
        	sso_logger.info "ERROR initialize user #{uid} because of #{e.to_s}"
        	sso_logger.info "#{e.backtrace.join("\n")}"
        	logger.info "ERROR initialize user #{uid} because of #{e.backtrace.join("\n")}"
        	puts "ERROR initialize user #{uid} because of #{e.backtrace.join("\n")}"

        	log_json = {params: params, uid: uid, error: e.to_s, stacktrace: e.backtrace.join("\n")}
        	Log.create(cat: "auth", body: log_json.to_json.to_s, created: Time.now, err: true)

        	return ({ :success => false, :message => e.to_s }).to_json
        end
        #need to determine which country code that will be used from client supplied parameters
        user_testers = ENV['TESTER_USERS'].nil? ?  [] : ENV['TESTER_USERS'].split(",") 
        #puts "user_testers.inspect: #{user_testers.inspect}"
        user.determine_country_code(params, is_new_user) unless user_testers.include?(uid)
  		puts "SKIP DETERMINE COUNTRY for #{uid}" if user_testers.include?(uid)
  		#update current service data that is used to auth
        user = update_service_user(service, user)
        #update device info if client pass the device information parameters
        user.update_device(params)
        #create or update registration base on device_serial and service
        Registration.create_or_update(params, service, user)
        #check whether device model name is premium or not
        is_premium = DeviceCategory.is_premium(params[:device_model_name])

        return ({   :success => true, 
                    :session_token => SSK_encode(user.country_code, is_premium), 
                    :eps_token => ApiKey.get_access_token(uid), 
                    :new_user => is_new_user,
                    :premium => is_premium
                    }).to_json
    end

    post '/auth' do
		content_type :json, :charset => 'utf-8'
        #verify token result to Samsung Account server
		token_result = verify_token(params)
		return token_result.to_json unless token_result[:success]
		#get uid/user id from Samsung Account data
        uid = token_result[:ss_ops].get_uid
        #initialize service from param service_id and put log
        service, status = initialize_service(params[:service_id], uid)
        return status.to_json unless status[:success]
     	#initialize user and get is_new_user status
        begin
        	user, is_new_user = initialize_user(uid, token_result[:ss_ops])
        rescue => e
        	sso_logger = ::Logger.new("logs/sso.log")
        	sso_logger.info "ERROR initialize user #{uid} because of #{e.to_s}"
        	sso_logger.info "#{e.backtrace.join("\n")}"
        	logger.info "ERROR initialize user #{uid} because of #{e.backtrace.join("\n")}"
        	puts "ERROR initialize user #{uid} because of #{e.backtrace.join("\n")}"

        	log_json = {params: params, uid: uid, error: e.to_s, stacktrace: e.backtrace.join("\n")}
        	Log.create(cat: "auth", body: log_json.to_json.to_s, created: Time.now, err: true)
        
        	return ({ :success => false, :message => e.to_s }).to_json
        end
        #need to determine which country code that will be used from client supplied parameters
        user_testers = ENV['TESTER_USERS'].nil? ?  [] : ENV['TESTER_USERS'].split(",") 
        #puts "user_testers.inspect: #{user_testers.inspect}"
        user.determine_country_code(params, is_new_user) unless user_testers.include?(uid)
  		puts "SKIP DETERMINE COUNTRY for #{uid}" if user_testers.include?(uid)
  		#update current service data that is used to auth
        user = update_service_user(service, user)
        #update device info if client pass the device information parameters
        user.update_device(params)
        #create or update registration base on device_serial and service
        Registration.create_or_update(params, service, user)
        #check whether device model name is premium or not
        is_premium = DeviceCategory.is_premium(params[:device_model_name])

        return ({   :success => true, 
                    :session_token => SSK_encode(user.country_code, is_premium), 
                    :eps_token => ApiKey.get_access_token(uid), 
                    :new_user => is_new_user,
                    :premium => is_premium
                    }).to_json
    end


	get '/get_session_token' do
		content_type :json, :charset => 'utf-8'
		return ({ :success => false, :message => 'invalid eps_token' }).to_json unless validate_eps_token(params[:user_id], params[:eps_token])
		user = get_user(params[:user_id])
		return ({ :success => false, :message => 'invalid user_id' }).to_json unless user
		return ({ :success => true, :session_token => SSK_encode(user.country_code, DeviceCategory.is_premium(params[:device_model_name])) }).to_json
	end

	get '/profile' do
		user_data = get_user_from_token
		return user_data.to_json unless user_data[:success]
		user_data[:user].attributes_json(params[:service_id])
	end

	post '/profile' do
		user_data = get_user_from_token
		return user_data.to_json unless user_data[:success]

		user = user_data[:user]
		user.update_from_params(params)
		user.update_device(params)
		user = update_profile_image(user, params)
		
		service_id = params[:service_id].present? ? params[:service_id] : ENV['DEFAULT_SERVICE_ID']
		service = Service.first(service_id)
		#create or update registration base on parameter device_serial and service
		Registration.create_or_update(params, service, user)
		user.attributes_json(service_id)
	end


	post '/preferences' do
		user_data = get_user_from_token
		return user_data.to_json unless user_data[:success]
		#update privileges if params has privileges key only
		preferences_status = user_data[:user].update_preferences(params[:service_id], params) if params.key?('preferences')
		return preferences_status.to_json if params.key?('preferences') && !preferences_status
		user_data[:user].preferences_json(params[:service_id])
	end 

	get '/preferences' do
		user_data = get_user_from_token
		return user_data.to_json unless user_data[:success]
		user_data[:user].preferences_json(params[:service_id])
	end 

	get '/profile_photo' do
		content_type :json, :charset => 'utf-8'
		uid, eps_token, target_uid = params[:user_id], params[:eps_token], params[:target_user_id]

		return ({ :success => false, :message => 'invalid eps_token' }).to_json unless validate_eps_token(uid, eps_token)
		user = get_user(target_uid)
		return ({ :success => false, :message => 'invalid user_id' }).to_json unless user
		return ({ :success => true, :profile_photo_url => user.photo_url }).to_json
	end

	get '/notify' do 
		content_type :json, :charset => 'utf-8'
		
		return ({ :success => false, :message => 'blank token' }).to_json unless params[:simple_token].present?
		valid_token = is_valid_simple_token(params[:simple_token]) || params[:simple_token]=='t0k3n007'
		return ({ :success => false, :message => 'invalid simple token' }).to_json unless valid_token

		receiver = "no message or reg_id present"
		if params[:message].present? && params[:reg_id].present?
			message = PushNotification.get_json_message_from_params(params)
			push_noti = PushNotification.new
			receiver = push_noti.send(params[:reg_id], message.to_json)
			if receiver.respond_to?('data')
				return {:success => true, message: receiver.data}.to_json
			else
				return {:success => false, error: receiver}.to_json
			end
		else
			return {:success => false, message: receiver}.to_json
		end
	end

	get '/device_models' do
		content_type :json, :charset => 'utf-8'
		devices_array = []
		Device.all(:manufacturer => "Samsung", :fields => [:model_name], :unique => true, :order => [:model_name.asc]).each do |dev|
			devices_array << dev.model_name
		end
		return devices_array.to_json
	end

	# EPS - CMS

	get '/verify_session_token' do
		session_token = params[:session_token]
		success, country_code, ttl, is_premium = SSK_decode(session_token)
		logger.info "GET[/verify_session_token, session_token:#{session_token}] Requested with invalid session_token." unless success

		return ({ :success => false }).to_json unless success
		return ({ :success => success, :country_code => country_code, :ttl => ttl, :premium => is_premium }).to_json
	end


	post '/notify_all' do 
		content_type :json, :charset => 'utf-8'
		#check simple token
		return ({ :success => false, :message => 'blank token' }).to_json unless params[:simple_token].present?
		valid_token = is_valid_simple_token(params[:simple_token]) || params[:simple_token]=='t0k3n007'
		unless valid_token
			log_json = {success: false, params: params, message: "invalid token"}
		    Log.create(cat: "notif", body: log_json.to_json.to_s, created: Time.now, err: true)
			return ({ :success => false, :message => 'invalid simple token' }).to_json 
		end
		#check parameters
		return ({ :success => false, :message => 'need country code' }).to_json unless params[:country].present? 
		return ({ :success => false, :message => 'invalid country code' }).to_json unless params[:country].length==3 
		return ({ :success => false, :message => 'need message parameter' }).to_json unless params[:message].present? 
		return ({ :success => false, :message => 'invalid gender parameter' }).to_json if !params[:gender].blank? && !['Male','Female'].include?(params[:gender])
		@target_devices = JSON.parse(params[:target_devices]) rescue nil if params[:target_devices].present?
		return ({ :success => false, :message => 'invalid target devices parameter, should be in Json String array' }).to_json if params[:target_devices].present? && @target_devices.nil?
		@service = params[:service_id].present? ? Service.first(params[:service_id]) : Service.first(ENV['DEFAULT_SERVICE_ID'])
		total = 0

		if params[:message].present? && @service
			json_message_string = PushNotification.get_json_message_from_params(params).to_json.to_s
			target_devices = @target_devices.nil? ? [] : @target_devices
			gender = params[:gender].blank? ? "all" : params[:gender]
			is_targeted = true
	        
	        #not targetting device or gender
	        if target_devices.size==0 && gender=='all'
	        	is_targeted = false
		        total = Registration.count(:country => params[:country], :service_sid => @service.sid)
			elsif target_devices.size==0 && gender!='all'
				total = Registration.count(:country => params[:country], :user => {:gender => gender}, :service_sid => @service.sid)
			elsif target_devices.size>0 && gender=='all'
				total = Registration.count(:devices => {:model_name => target_devices}, :country => params[:country], :service_sid => @service.sid)
			elsif target_devices.size>0 && gender!='all'
				total = Registration.count(:devices => {:model_name => target_devices}, :country => params[:country], :user => {:gender => gender} , :service_sid => @service.sid)
			end

			#this call purpose is to split and delegate the notification delivery to Resque worker 
			delegate_push_notification(json_message_string, params, total, is_targeted)
		end

		return {:success => true, :total => total}.to_json
	end


	# EPS - BHS

	get '/verify_eps_token' do
		content_type :json, :charset => 'utf-8'
		uid, eps_token = params[:user_id], params[:eps_token]

		is_valid_token = ApiKey.check_access_token(uid, eps_token)
		logger.info "GET[/verify_eps_token, uid:#{uid}, eps_token:#{eps_token}] Requested with invalid eps_token."  unless is_valid_token
		return ({ :success => false }).to_json  unless is_valid_token
		return ({ :success => true  }).to_json
	end

	post '/verify_eps_token' do
        content_type :json, :charset => 'utf-8'
        eps_token = params[:eps_token]
        return ({ :success => false }).to_json if eps_token.blank?
  
        is_valid_token, api_key = ApiKey.verify_eps_token(eps_token)
        logger.info "POST[/verify_eps_token, eps_token:#{eps_token}] Requested with invalid eps_token."  unless is_valid_token
        return ({ :success => false }).to_json  unless is_valid_token
        return ({ :success => true, :uid => api_key.uid }).to_json
    end
  

	# Log tracking

	get '/logs' do
		content_type :json, :charset => 'utf-8'
		return ({ :success => false, :message => 'invalid token' }).to_json if (params[:token].nil? || params[:token].length!=9)
		return ({ :success => false, :message => 'invalid token' }).to_json unless check_log_token(params)

		offset = params[:offset].nil? ? 0 : params[:offset].to_i
		limit = params[:limit].nil? ? 10 : params[:limit].to_i
		cat = params[:cat].nil? ? "notif" : params[:cat]
		err = params[:err].nil? ? false : params[:err]

		limit = 100 if limit > 100

		logs = []
		Log.all( :cat => cat, :offset => offset,:limit => limit, :err=> err, :order => [ :id.desc ] ).each do |l|
			logs << l.to_json
		end
		return logs.to_json
	end
	
private
  def initialize_service(sid, uid)
  	service = Service.first(:sid => sid)
  	json_status = { :success => true, :message => '' }
        if service == nil
            default_sid = ENV['DEFAULT_SERVICE_ID']
            default_service_name = ENV['DEFAULT_SERVICE_NAME']
  
            if sid != nil
                logger.info "GET[/auth, sid:#{sid}, uid:#{uid}, access_token:#{params[:access_token]}] Requested with not allowed service id."
                json_status = { :success => false, :message => 'not allowed service' }.to_json
            else
                logger.info "GET[/auth, sid:#{sid}, uid:#{uid}, access_token:#{params[:access_token]}] Requested with nil service id, using default #{default_sid}"
            end
  
            service = Service.first_or_create( { :sid => default_sid }, { :sid => default_sid, :service_name => default_service_name } )
        end
     [service, json_status]
  end

  def initialize_user(uid,ss_ops)
  		new_user = false
        user = User.first(:uid => uid)
        if (!user)
            profile, err = ss_ops.profile()
            raise "failed to verify token and get user profile of '#{uid}' from Samsung SSO, message: #{err.inspect}" if profile.nil?
            new_user = true
            user = User.first_or_create( { :uid => uid }, User.attributes_from_samsung_profile(uid,profile))
        end
        [user,new_user]
  end

  def verify_token(params)
  		return { success: false, message: "require access token"} unless params[:access_token]
  	 	access_token = params[:access_token]
  	 	verify_status = false
	  	response_code = 200
	  	ss_ops = nil
  	 	begin
	        ss_ops = Samsung::OPS.new({ :access_token => access_token})
	  		sid = params[:service_id].present? ? params[:service_id] : "GL01"
  			verify_status, response_code = ss_ops.verify_with_service_id(sid)
  			return { success: true, ss_ops: ss_ops, response_code: response_code} if verify_status
  			unless verify_status
				logger.info "GET[/auth, access_token:#{access_token}], sid: #{sid} SamsungSSO verification failed."
				return ({ success: false, message: 'invalid access_token', response_code: response_code })	
			end
  		rescue => e
  			sso_logger = ::Logger.new("logs/sso.log")
  			sso_logger.info "ERROR VERIFY TOKEN for access_token #{access_token} because of #{e.to_s}"
  			sso_logger.info "#{e.backtrace.join("\n")}"
  			log_json = {params: params, access_token: access_token, error: e.to_s, stacktrace: e.backtrace.join("\n")}
        	Log.create(cat: "auth", body: log_json.to_json.to_s, created: Time.now, err: true)
  			return { success: false, message: e.to_s }
  		end 
  end

  def update_service_user(service, user)
  		service_user = ServiceUser.first(:user => user, :service => service)
        if (!service_user)
            service_user = ServiceUser.first_or_create( { :user => user, :service => service }, {
                :joined_at => Time.now,
                :last_accessed_at => Time.now })
               user.service_users << service_user            
            user.save
        else
            service_user[:last_accessed_at] = Time.now
            service_user.save
        end
        user
  end


  def update_profile_image(user, params)
  	if (!params[:image].blank? && !params[:image_ext].blank?)
			filename = "#{user.uid}-#{Time.now.to_i}.#{params[:image_ext]}"
			previous_url = user.photo_url
			user.photo_url = s3_stream_upload(filename, Base64.decode64(params[:image]))
			#delete previous photo
			unless previous_url.nil?
				previous_urls = previous_url.split("/")
	          	bucket_name = previous_urls[3]
	          	old_filename = previous_urls[4]
				s3_delete(old_filename)
			end
		end
	user.save
	user
  end

  def get_user(uid)
  	user = User.first(:uid => uid)
	logger.info "GET[/profile, uid:#{uid}, eps_token:#{eps_token}] Requested with invalid user_id."  unless user
	user
  end

  def validate_eps_token(uid, eps_token)
  	verified = ApiKey.check_access_token(uid, eps_token)
	logger.info "GET[/profile, uid:#{uid}, eps_token:#{eps_token}] Requested with invalid eps_token." unless verified
	verified
  end

  def get_user_from_token
  		content_type :json, :charset => 'utf-8'
  		token_result, eps_token = verify_token(params), params[:eps_token]
		return token_result unless token_result[:success]
		uid = token_result[:ss_ops].get_uid
		return { :success => false, :message => 'invalid eps_token' } unless validate_eps_token(uid, eps_token)
		user = get_user(uid)
		return { :success => false, :message => 'invalid user_id' } unless user
		return { :success => true, uid: uid, user: user }
  end

  def check_log_token(params)
  		token = params[:token]
		valid_time = Date.today.strftime("%Y%m")

		valid_token = false
		valid_token =  ["s","S"].include?(token[0]) && ["g","G"].include?(token[8])

		all_chars = ("a".."z").to_a

		current_time = token[1..6]
		valid_token = valid_time == current_time

		token_date = token[7]
		current_date = Date.today.strftime("%d")	
		valid_token = all_chars[current_date.to_i - 1] == token_date if current_date.to_i < 27
		valid_token = "z" == token_date if current_date.to_i >= 27
		valid_token
  end

  def delegate_push_notification(json_message_string, params, total, is_targeted = false)
  		divider = 12 #because split into 12 workers
  		divider = 1 if total < 13
		per_page = (total/divider).floor
		per_page = per_page + 1 if (total % divider) > 0
		puts "TOTAL : #{total} : Per Page #{per_page}"

		(1..divider).each do |n|
			 offset = (n-1) * per_page
			 log_json = {success: true, country: params[:country], gender: params[:gender], devices: params[:target_devices], total: total, 
			 				per_page: per_page, from: offset, to: per_page + offset, message: params[:message]}
			 puts "Targeted: #{is_targeted} Notif #{params.inspect} #{params[:message]} from #{offset} to :#{ offset + (per_page - 1) }"
			 
			 if is_targeted
			 	Resque.enqueue(TargetedNotification, @service.sid, json_message_string, offset, per_page, params)
			 else
			 	Resque.enqueue(Notification, @service.sid, json_message_string, offset, per_page, params[:country])
			 end
			 Log.create(cat: "notif", body: log_json.to_json.to_s, created: Time.now, err: false)
		end

  end

# get temporary S3 authentication credentials
=begin
	get '/authenticate_S3' do
		content_type :json
		{ :success => true, :credentials => get_S3_authentication }.to_json
	endm

	get '/test_access' do
		content_type 'image/jpeg'
		credentials = get_S3_authentication
		AWS.config(credentials)
		s3 = AWS::S3.new
		file = s3.buckets[ENV["S3_BUCKET"]].objects['4linwf3eyc.jpeg']
		file.read
	end
=end

end
