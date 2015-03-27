require 'dm-migrations/migration_runner'

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.logger.debug("Starting cleaning up")

migration 1, :drop_table_allowed_apps do
  up do
    drop_table :allowed_apps
  end
end

migration 2, :drop_device_info_columns_from_users_table do
  up do
    modify_table :users do
      drop_column :device_model
      drop_column :device_build_serial
      drop_column :device_serial
      drop_column :device_android_id
      drop_column :gl_join_date
      drop_column :last_access_date
    end
  end
end

DataMapper.logger.debug("Completed cleaning up")