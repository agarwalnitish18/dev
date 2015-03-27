# encoding: utf-8

class Device
  include DataMapper::Resource

  property :id, Serial

  property :added_date, DateTime
  property :manufacturer, String
  property :model_name, String
  property :os_version, String
  property :serial, String, :index => true

  property :android_id, String
  property :country, String
  property :serial_number, String
  property :imei, String
  property :network_carrier, String
  property :last_location, String
  property :last_used_at, DateTime

  property :phone_number, String, :allow_nil => true

  property :sim_country, String
  property :network_country, String
  property :gps_country, String

  property :mac_address, String
  property :mcc, String
  property :mnc, String

  property :size, Float

  belongs_to :user
end