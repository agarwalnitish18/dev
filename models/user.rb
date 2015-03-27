# encoding: utf-8

class User
  include DataMapper::Resource

  property :uid, String, :key => true, :format => /^\w+$/
  # synced Samsung API profile fields
  property :prefix, String, :allow_nil => true, :allow_nil => true
  property :family_name, String, :length => 100, :allow_nil => true
  property :given_name, String, :length => 100, :allow_nil => true
  property :birthday, String
  property :email, String
  property :receive_email_newsletter, String
  property :country_code, String
  property :address_type_text, String, :allow_nil => true
  property :address_type_sequence , String, :allow_nil => true
  property :address_location_type_text, String, :allow_nil => true
  property :address_type_detail_text, String, :allow_nil => true
  property :postal_code_text, String, :allow_nil => true
  #below is field to save samsung account original country_code
  property :country_code_sa, String 

  # extended profile fields
  property :photo_url, String, :length => 200
  property :gender, String
  property :primary_phone_number, String, :allow_nil => true
  property :fb_connect_uid, String
  property :last_updated_at, DateTime

  #the new profile image fields without full url
  property :photo_key, String, :length => 100
  property :bucket, String, :length => 100

  has n, :devices

  has n, :service_users
  has n, :services, :through => :service_users

def update_device(params)
    if (params[:device_manufacturer].present? && params[:device_model_name].present? && params[:device_os_version].present? && params[:device_serial].present?)
      device = self.devices.first(:serial => params[:device_serial])
      mac_address = params[:device_mac_address].blank? ? "" : params[:device_mac_address].gsub("%3A",":")
      if (!device)
        device = self.devices.create(
          :added_date => Time.now,
          :manufacturer => params[:device_manufacturer],
          :model_name => params[:device_model_name],
          :os_version => params[:device_os_version],
          :serial => params[:device_serial],
          :android_id => params[:device_android_id],
          :country => self.country_code,
          :serial_number => params[:device_serial_number],
          :network_carrier => params[:device_network_carrier],
          :last_location => params[:device_location],
          :imei => params[:device_imei],
          :phone_number => params[:device_phone_number],
          :last_used_at => Time.now,
          :sim_country => params[:sim_country],
          :network_country => params[:net_country],
          :gps_country => params[:gps_country],
          :mac_address => mac_address,
          :mcc => params[:device_mcc],
          :mnc => params[:device_mnc],
          :size => params[:device_size]
          )
      else
        device.attributes = {
          :manufacturer => params[:device_manufacturer],
          :model_name => params[:device_model_name],
          :os_version => params[:device_os_version],
          :android_id => params[:device_android_id],
          :country => self.country_code,
          :serial_number => params[:device_serial_number],
          :network_carrier => params[:device_network_carrier],
          :last_location => params[:device_location],
          :imei => params[:device_imei],
          :phone_number => params[:device_phone_number],
          :mac_address => mac_address,
          :mcc => params[:device_mcc],
          :mnc => params[:device_mnc],
          :size => params[:device_size],
          :last_used_at => Time.now }
        device.save
      end
    end
 end

 def get_active_service(service_id)
    self.service_users.first(service_sid: service_id)
 end

 def self.attributes_from_samsung_profile(uid,profile)
                {
                :uid => uid,
                :email => profile[:email],
                :birthday => profile[:birthday],
                :prefix => profile[:name][:prefix],
                :family_name => profile[:name][:family],
                :given_name => profile[:name][:given],
                :country_code => profile[:country_code],
                :address_type_text => profile[:address_type_text],
                :address_type_sequence => profile[:address_type_sequence],
                :address_location_type_text => profile[:address_location_type_text],
                :address_type_detail_text => profile[:address_type_detail_text],
                :postal_code_text => profile[:postal_code_text],
                :last_updated_at => Time.now }
 end

 def update_from_params(params)
    #prevent email, birthday, gender to have blank/null value, because all of them must be set
    self.email = params[:email] unless params[:email].blank? || params[:email] == 'null'
    self.birthday = params[:birthday] unless params[:birthday].blank? || params[:birthday] == 'null'
    self.gender = params[:gender] unless params[:gender].blank? || params[:gender] == 'null'
    self.receive_email_newsletter = params[:receive_email_newsletter] unless params[:receive_email_newsletter].blank? || params[:receive_email_newsletter] == 'null'

    attribute_names = [:prefix,:family_name,:given_name,:postal_code_text,:primary_phone_number,
                      :address_type_text,:address_type_sequence,:address_type_detail_text,:address_location_type_text]
    attribute_names.each do |attr_name|
        #attribute can be set if not nill, if blank string and not 'null' string
        unless params[attr_name].blank? || params[attr_name] == 'null'
            self.attribute_set(attr_name,params[attr_name])
        end
        if !params[attr_name].nil? && params[attr_name].empty? 
            self.attribute_set(attr_name,nil)
        end
    end                  
 end

  #Check country code is supported or not
  def self.from_supported_country(country_code)
      puts "PLEASE CONFIGURE ENV['SUPPORTED_COUNTRY_CODES']" if ENV['SUPPORTED_COUNTRY_CODES'].nil?
      return false if ENV['SUPPORTED_COUNTRY_CODES'].nil?
      return true if ENV['SUPPORTED_COUNTRY_CODES'].split(",").include?(country_code.upcase)
      false
  end

  #Determine country code that will be used by user
  #EPS will check three country_code parameters from client
  #and use the order to select country
  def determine_country_code(params, new_user)
      #keep original country code from samsung account to country_code_sa if user is new_user
      self.country_code_sa = self.country_code if new_user
      device = nil
      if params.key?('device_serial')
             device = self.devices.first(:serial => params[:device_serial])
             unless device.nil?
               device.sim_country = params[:sim_country] unless params[:sim_country].nil? 
               device.network_country = params[:net_country] unless params[:net_country].nil? 
               device.gps_country = params[:gps_country] unless params[:gps_country].nil? 
               device.save
             end
      end

      [:sim_country, :gps_country, :net_country].each do |country_key|
        if params.key?(country_key.to_s) && params[country_key].length==3 && User.from_supported_country(params[country_key])
          #update user country code if country_code parameter is supported country_code base on the priority "country" order
          self.country_code = params[country_key]
          unless device.nil?
            device.country = params[country_key] 
            device.save
          end
          break
        end
      end
      self.save
      puts "determine country user: #{self.uid}, country_code: #{self.country_code}, sim: #{params[:sim_country]}, net: #{params[:net_country]}, gps: #{params[:gps_country]}"
      puts "device serial: #{device.serial}, country: #{device.country}, sim: #{device.sim_country}, gps:#{device.gps_country}, net:#{device.network_country}" unless device.nil?
  end

  def attributes_json(service_id)
      usrvals = self.attributes
      usrvals[:devices] = self.devices.collect { |d| 
        dev_attributes = d.attributes
        dev_attributes[:last_used_at_u] = d.last_used_at.to_i
        dev_attributes[:added_date_u] = d.added_date.to_i
        dev_attributes
       }
      usrvals[:success] = true
      sid = service_id.nil? ? ENV['DEFAULT_SERVICE_ID'] : service_id
      active_service = get_active_service(sid)
      usrvals[:joined_date] = active_service.nil? || active_service.joined_at.nil? ? nil : active_service.joined_at.strftime("%Y%m%d") 
      usrvals[:joined_date_u] = active_service.nil? || active_service.joined_at.nil? ? nil : active_service.joined_at.to_i
      usrvals[:last_updated_at_u] = last_updated_at.to_i
      preferences = JSON.parse(active_service.preferences) rescue nil
      usrvals[:preferences] = preferences
      usrvals.to_json
  end

  def preferences_json(service_id)
      usrvals = { success: true, uid: self.uid }
      sid = service_id.nil? ? ENV['DEFAULT_SERVICE_ID'] : service_id
      active_service = get_active_service(sid)
      preferences = JSON.parse(active_service.preferences) rescue nil
      usrvals[:preferences] = preferences
      usrvals.to_json
  end

  def update_preferences(service_id, params)
      preferences_data = JSON.parse(params[:preferences]) rescue nil
      return { :success => false, :message => 'invalid preferences value, must be valid json' } if preferences_data.nil?
      sid = service_id.nil? ? ENV['DEFAULT_SERVICE_ID'] : service_id
      active_service = get_active_service(sid)
      active_service.preferences = preferences_data.to_json
      active_service.save
      { :success => true }
  end

end

class Service
  include DataMapper::Resource

  property :sid, String, :key => true, :format => /^\w+$/

  # service properties
  property :service_name, String
  property :client_id, String
  property :client_secret, String

  has n, :service_users
  # has n, :users, :through => :service_users
end

class ServiceUser
  include DataMapper::Resource

  property :joined_at, DateTime
  property :last_accessed_at, DateTime
  property :preferences, Text, :allow_nil => true

  belongs_to :user, :key => true
  belongs_to :service, :key => true
end