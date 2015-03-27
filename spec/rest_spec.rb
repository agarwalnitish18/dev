ENV['RACK_ENV'] = 'test'

require_relative './spec_helper.rb'
require 'rspec'
require 'rack/test'

ACCESS_TOKEN = 'Cth2JRrP3A'

class Storage
  attr_accessor :eps_token, :user_id, :session_token
  attr_writer :eps_token, :user_id, :session_token

  def initialize
    @eps_token = ''
    @user_id = ''
    @session_token = ''
  end 

end


describe 'EPS API' do
  include Rack::Test::Methods

  def app
    SamsungExtendedProfileApp.new
  end

  before (:all) do 
      @storage =  Storage.new 
  end

  it "AUTH" do
  	body = "?access_token=#{ACCESS_TOKEN}"
    get '/auth' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)

    @storage.eps_token = data['eps_token']
    @storage.session_token = data['session_token']

    expected_keys = ['session_token', 'eps_token', 'new_user', 'premium']
    all_keys_exists = true
    expected_keys.each do |k,v|
      all_keys_exists = false unless data.include?(k)
    end
    all_keys_exists.should == true
  end


  it "GET PROFILE" do
    body = "?access_token=#{ACCESS_TOKEN}&eps_token=#{@storage.eps_token}"
    get '/profile' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true) 
    @storage.user_id = data['uid'] 

    expected_keys = ["uid","prefix","family_name","given_name", "birthday","email", "receive_email_newsletter","country_code", "address_type_text", 
    "address_type_sequence", "address_location_type_text", "address_type_detail_text", "postal_code_text","country_code_sa", "photo_url", 
    "gender", "primary_phone_number","fb_connect_uid", "last_updated_at","photo_key", "bucket", "success", "joined_date"]
    all_keys_exists = true
    expected_keys.each do |k,v|
      all_keys_exists = false unless data.include?(k)
    end
    all_keys_exists.should == true
  end

  it "POST PROFILE" do
    body = "?access_token=#{ACCESS_TOKEN}&eps_token=#{@storage.eps_token}"
    get '/profile' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true) 

    family_name, given_name = data['family_name'], data['given_name']

    params = {access_token: ACCESS_TOKEN,
              eps_token: @storage.eps_token,
              family_name: family_name + " 123",
              given_name: given_name + " 123"
             }

    post '/profile', params
    data = JSON.parse(last_response.body)
    expect(data['family_name']).to eq(family_name + " 123") 
    expect(data['given_name']).to eq(given_name + " 123") 
    
    params = {access_token: ACCESS_TOKEN,
              eps_token: @storage.eps_token,
              family_name: family_name,
              given_name: given_name
             }
    post '/profile', params
    data = JSON.parse(last_response.body)
    expect(data['family_name']).to eq(family_name) 
    expect(data['given_name']).to eq(given_name) 
  end

  it "GET PROFILE PHOTO" do
    body = "?access_token=#{ACCESS_TOKEN}&eps_token=#{@storage.eps_token}&user_id=#{@storage.user_id}&target_user_id=#{@storage.user_id}"
    get '/profile_photo' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)    
  end

   it "GET SESSION TOKEN" do
    body = "?eps_token=#{@storage.eps_token}&user_id=#{@storage.user_id}"
    get '/get_session_token' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)  

    expected_keys = ['success','session_token']  
    all_keys_exists = true
    expected_keys.each do |k,v|
      all_keys_exists = false unless data.include?(k)
    end
    all_keys_exists.should == true
  end

  it "VERIFY SESSION TOKEN" do
    body = "?session_token=#{@storage.session_token}"
    get '/verify_session_token' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)  

    expected_keys = ["success", "country_code", "ttl", "premium"]
    all_keys_exists = true
    expected_keys.each do |k,v|
      all_keys_exists = false unless data.include?(k)
    end
    all_keys_exists.should == true
  end


  it "VERIFY EPS TOKEN" do
    body = "?user_id=#{@storage.user_id}&eps_token=#{@storage.eps_token}"
    get '/verify_eps_token' + body

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)  
  end

   it "POST PREFERENCES" do
     pref_json = %{{
      "interests": [
          "jazz",
          "design",
          "internet",
          "music"
      ],
      "saved_privileges": [
          {
              "id": "P21",
              "expiry": 14434444
          },
          {
              "id": "P134",
              "expire": 13334444
          }
      ],
      "verified_privileges": [
          {
              "id": "P21",
              "expiry": 14434444
          },
          {
              "id": "P134",
              "expire": 123456
          }
      ]
    }}
    
    params = {access_token: ACCESS_TOKEN,
              eps_token: @storage.eps_token,
              preferences: pref_json
             }
    post '/preferences',  params

    data = JSON.parse(last_response.body)
    expect(data['success']).to eq(true)  
  end

  it "GET PREFERENCES" do
    body = "?access_token=#{ACCESS_TOKEN}&eps_token=#{@storage.eps_token}"
    get '/preferences' + body

    pref_json_string = %{{
      "interests": [
          "jazz",
          "design",
          "internet",
          "music"
      ],
      "saved_privileges": [
          {
              "id": "P21",
              "expiry": 14434444
          },
          {
              "id": "P134",
              "expire": 13334444
          }
      ],
      "verified_privileges": [
          {
              "id": "P21",
              "expiry": 14434444
          },
          {
              "id": "P134",
              "expire": 123456
          }
      ]
    }}

    pref_json = JSON.parse(pref_json_string)
    data = JSON.parse(last_response.body)
    expect(data['preferences'] == pref_json).to eq(true) 

    expect(data['success']).to eq(true)  
  end

end