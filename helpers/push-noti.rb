class PushNotification
		def initialize
			@sns = AWS::SNS.new(
	  			:access_key_id => ENV['SNS_ACCESS_KEY_ID'],
	  			:secret_access_key => ENV['SNS_SECRET_ACCESS_KEY'],
	  			:region => 'ap-southeast-1'
	  			)
		end

		def send(reg_id, payload)
			begin
				target_arn = @sns.client.create_platform_endpoint({
					:platform_application_arn => ENV['AWS_SNS_APP_ARN'], 
					:token => reg_id})

				@sns.client.set_endpoint_attributes(
					:endpoint_arn => target_arn.endpoint_arn, 
					:attributes => { 'Enabled' => 'true'})
				
				@sns.client.publish(
					:target_arn => target_arn.endpoint_arn,
					:message => payload,
					:subject => 'New Galaxy Life Notification',
					:message_structure => 'json')

			rescue => e
				p "Push notification sending failure to " + reg_id
				p e.backtrace.to_json
				log_json = {reg_id: reg_id, payload: payload, message: e.to_s, stacktrace:  e.backtrace.join("\n\t")}
         	    Log.create(cat: "notif", body: log_json, created: Time.now, err: true)
				{message: e.message, error: e.message}
			end
		end

		def self.get_json_message_from_params(params)
			item_id = params[:item_id].present? ? params[:item_id] : ""
			item_name = params[:item_name].present? ? params[:item_name] : ""
			action = item_id.blank? ? "" : "open_item"

			gcm_json = { 
				:data => {
					:title => params[:message],
					:message => params[:message],
					:item_id => item_id,
					:item_name => item_name,
					:action => action
				}
			}

			message = {
			      :default => params[:message],
			      :GCM => gcm_json.to_json.to_s
			}

			message
		end
end
