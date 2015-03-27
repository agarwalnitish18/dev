# encoding: utf-8

class Registration
  include DataMapper::Resource

  property :id, Serial
  property :serial, String, :index => true
  property :reg_id, String, :length => 255
  property :country, String

  belongs_to :service
  belongs_to :user

  has n, :devices, :parent_key => [:serial], :child_key => [:serial]

  #create or update existing registration from parameters value, service and user
  def self.create_or_update(params, service, user)
  	   if params[:device_serial].present? && params[:reg_id].present? && params[:reg_id].length >= 90 
        	reg = Registration.first(:service => service, :serial => params[:device_serial])
          
            if reg
            	reg.country = user.country_code
            	reg.user = user
            	reg.reg_id = params[:reg_id]
            	reg.save
            else
              Registration.create(
                  :reg_id => params[:reg_id],
                  :user => user,
                  :service => service,
                  :serial => params[:device_serial],
                  :country => user.country_code
                  )
            end

        elsif params[:device_serial].present? && !params[:reg_id].present?
            reg = Registration.first(:service => service, :serial => params[:device_serial])
            if reg && reg.country!=user.country_code
              reg.country = user.country_code
              reg.save
            end
        end
  end

end