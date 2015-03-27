DataMapper::Logger.new(STDOUT, :debug)
DataMapper.logger.debug("Starting Create Initial Device Category data")
  
initial_datas = [
					{model_name: "SM-G900", is_premium: true}
				]

initial_datas.each do |data|
	DeviceCategory.create(model_name: data[:model_name], is_premium: data[:is_premium])
end
  
DataMapper.logger.debug("Completed Create Initial Device Category data")
