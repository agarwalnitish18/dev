# encoding: utf-8
require 'active_support/all'

class ApiKey
  include DataMapper::Resource

  property :uid, String,
           :key => true,
           :format => /^\w+$/,
           :unique => true
  property :eps_token, String, :unique => true
  property :created_at, DateTime

  def self.get_access_token(uid)
    apikey = ApiKey.first(:uid => uid)
    if (!apikey)
      apikey = ApiKey.create(:uid => uid, :created_at => ENV['EPS_TOKEN_EXPIRE_HOURS'].to_i.hours.ago)
    end

    if (apikey.created_at <= ENV['EPS_TOKEN_EXPIRE_HOURS'].to_i.hours.ago)
      begin
        apikey.eps_token = SecureRandom.hex
      end while self.first(:eps_token => eps_token)

      apikey.created_at = Time.now
      apikey.save
    end

    return apikey.eps_token
  end

  def self.check_access_token(uid, token)
    apikey = ApiKey.first(:uid => uid)
    if (!apikey)
      return false
    end

    return (token == apikey.eps_token)
  end

  def self.verify_eps_token(eps_token)
    apikey = ApiKey.first(:eps_token => eps_token)
    if (!apikey)
      return false, nil
    end

    return true, apikey
  end

end
