# encoding: utf-8

class DeviceCategory
  include DataMapper::Resource

  property :id, Serial
  property :manufacturer, String, :default => "Samsung"
  property :model_name, String, :unique => true
  property :is_premium, Boolean, :default  => false


  def self.is_premium(device_model_name)
  		is_premium = false
  		if device_model_name
            devs = DeviceCategory.all(:is_premium => true, :fields => [:model_name])
            devs.each do |device|
              is_premium = true unless device_model_name.index(device.model_name).nil?
              break if is_premium
            end
        end
      is_premium
  end

end