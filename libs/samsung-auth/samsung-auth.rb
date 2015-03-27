require 'base64'
require 'httparty'
require 'sinatra'
require 'logger'

module Samsung

  class OPS
    include HTTParty
    include Logger
    base_uri 'https://api.samsungosp.com'
    headers 'Content-Type' => 'text/xml'

    def initialize(configs)
      @logger = ::Logger.new("logs/sso.log")

      @client_id = configs[:client_id] || ENV['SAMSUNG_OPS_CLIENT_ID']
      @client_secret = configs[:client_secret] || ENV['SAMSUNG_OPS_CLIENT_SECRET']
      @user_id = nil
      @access_token = configs[:access_token]

      if (configs[:api_url])
        self.class.base_uri 'https://' + configs[:api_url]
      end

      self.class.headers 'x-osp-appId' => @client_id
    end

    def check()
      key = @client_id + ':' + @client_secret
      self.class.headers 'Authorization' => 'Basic ' + Base64.encode64(key)

      resp = self.class.get ''

      return resp.code == 200
    end

    # verify if the access token is valid
    def verify()
      key = @client_id + ':' + @client_secret
      self.class.headers 'Authorization' => 'Basic ' + Base64.encode64(key)

      resp = self.class.get '/v2/license/security/authorizeToken?authToken=' + @access_token

      return false if resp.code != 200
      return false unless resp['AuthorizeTokenResultVO']
      return false unless resp['AuthorizeTokenResultVO']['authenticateUserID']

      @user_id = resp['AuthorizeTokenResultVO']['authenticateUserID']

      return true
    end

       # verify if the access token is valid
    def verify_with_service_id(service_id)
      keys = self.get_keys_from_service_id(service_id)
      key =  keys[:client_id] + ':' + keys[:client_secret]
      #puts "SERVICE_ID: #{service_id}"
      #puts "KEY : #{key}"
      self.class.headers 'x-osp-appId' => keys[:client_id]
      self.class.headers 'Authorization' => 'Basic ' + Base64.encode64(key)

      start_time = Time.now
      @logger.info "SSO token: #{@access_token} call"
      resp = self.class.get '/v2/license/security/authorizeToken?authToken=' + @access_token
      finish_time = Time.now
      @logger.info "SSO token: #{@access_token} , response.code: #{resp.code}"

      if resp.code!=200 && resp.key?('error')
         @logger.info "SSO token: #{@access_token} , error: #{resp['error'].inspect}"
      end

      duration = finish_time - start_time
      duration_secs = duration * 1000
      @logger.info "SSO token: #{@access_token} , duration: #{duration} secs / #{duration_secs} ms"
      return [false, resp.code] if resp.code != 200
      return [false, resp.code] unless resp['AuthorizeTokenResultVO']
      return [false, resp.code] unless resp['AuthorizeTokenResultVO']['authenticateUserID']

      @user_id = resp['AuthorizeTokenResultVO']['authenticateUserID']

      [true, resp.code]
    end



    def get_keys_from_service_id(service_id)
      service = Service.first(:sid => service_id)
      #puts "service: #{service.service_name}"
      return {client_id: service.client_id,client_secret: service.client_secret} if service && !service.client_id.blank? && !service.client_secret.blank? 
      return {client_id: @client_id ,client_secret: @client_secret} if service.nil? || service.client_id.blank? || service.client_secret.blank?
    end

    def get_error_message(service_id='GL01') 
      key = get_keys_from_service_id(service_id)
      key =  keys[:client_id] + ':' + keys[:client_secret]
      self.class.headers 'Authorization' => 'Basic ' + Base64.encode64(key)

      resp = self.class.get '/v2/license/security/authorizeToken?authToken=' + @access_token
      return resp.key?("error") ? resp["error"] : ""
    end


    def get_uid()
      return @user_id
    end

    # get user profile data
    def profile()
      if (!self.verify())
        @logger.info "FAILED in self.verify() call, unable to verify token for #{@user_id}"
        return nil, { :error => { :message => "Unable to verify token for #{@user_id}" } }
      end
      
      self.class.headers 'Authorization' => 'Bearer ' + @access_token, 'x-osp-userId' => @user_id

      @logger.info "SSO get profile: #{@user_id} call"
      start_time = Time.now
      resp = self.class.get '/v2/profile/user/user/' + @user_id
      finish_time = Time.now
      @logger.info "SSO get profile: #{@user_id} , response.code: #{resp.code}" 
     
      if (resp['error'])
        @logger.info "SSO get profile for error: #{resp['error'].inspect}"
        return nil, { :error => { :message => 'Unable to verify user' } }
      end

      unless resp.key?('UserVO')
        @logger.info "SSO get profile error: #{resp['error'].inspect}"
        return nil, { :error => { :message => 'Unable to verify user' } }
      end

      duration = finish_time - start_time
      duration_secs = duration * 1000
      @logger.info "SSO get profile: #{@user_id} , duration: #{duration} secs / #{duration_secs} ms"

      profile = {}

      profile[:uid] = resp['UserVO']['userID']
      profile[:name] = {
        :prefix => resp['UserVO']['userBaseVO']['userBaseIndividualVO']['prefixName'],
        :family => resp['UserVO']['userBaseVO']['userBaseIndividualVO']['familyName'],
        :given  => resp['UserVO']['userBaseVO']['userBaseIndividualVO']['givenName'] }
      profile[:birthday] = resp['UserVO']['userBaseVO']['userBaseIndividualVO']['birthDate']
      profile[:email] = resp['UserVO']['userIdentificationVO']['loginID']
      profile[:receive_email_newsletter] = (resp['UserVO']['userBaseVO']['emailReceiveYNFlag'] == 'Y' ? 1 : 0)
      profile[:country_code] = resp['UserVO']['userBaseVO']['countryCode']

      if (resp['UserVO']['userContactAddressVO'])
        address = resp['UserVO']['userContactAddressVO']
        address = address[0] if (address.is_a?(Array))
        profile[:address_type_text] = address['addressTypeText']
        profile[:address_type_sequence] = address['addressTypeSequence']
        profile[:address_location_type_text] = address['addressLocationTypeText']
        profile[:address_type_detail_text] = address['addressTypeDetailText']
        profile[:postal_code_text] = address['postalCodeText']
      else
        profile[:address_type_text] = nil
        profile[:address_type_sequence] = nil
        profile[:address_location_type_text] = nil
        profile[:address_type_detail_text] = nil
        profile[:postal_code_text] = nil
      end

      return profile,  { :error => { :message => 'none' } }
    end
  end

end
