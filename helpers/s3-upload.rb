require 'aws-sdk'

module S3Upload

  def s3_check()
    AWS.config({ :access_key_id => ENV["S3_ACCESS_KEY_ID"], :secret_access_key => ENV["S3_SECRET_ACCESS_KEY"] })

    s3 = AWS::S3.new

    return s3.buckets[ENV["S3_BUCKET"]].exists?
  end

  def s3_upload(filename, file)
    AWS.config({ :access_key_id => ENV["S3_ACCESS_KEY_ID"], :secret_access_key => ENV["S3_SECRET_ACCESS_KEY"] })

    s3 = AWS::S3.new
    s3.buckets[ENV["S3_BUCKET"]].objects[filename].write(:file => file, :acl => :public_read)

    return 'https://' + ENV["S3_HOST"] + '/' + ENV['S3_BUCKET'] + '/' + filename
  end

  def s3_stream_upload(key, data)
    AWS.config({ :access_key_id => ENV["S3_ACCESS_KEY_ID"], :secret_access_key => ENV["S3_SECRET_ACCESS_KEY"] })

    s3 = AWS::S3.new
    s3.buckets[ENV["S3_BUCKET"]].objects[key].write(data, :acl => :public_read)

    return 'https://' + ENV["S3_HOST"] + '/' + ENV['S3_BUCKET'] + '/' + key
  end

  def s3_delete(key)
    return true if key.blank?
    AWS.config({ :access_key_id => ENV["S3_ACCESS_KEY_ID"], :secret_access_key => ENV["S3_SECRET_ACCESS_KEY"] })
    s3 = AWS::S3.new
    old_file_exists = s3.buckets[ENV["S3_BUCKET"]].objects[key].exists?
    s3.buckets[ENV["S3_BUCKET"]].objects[key].delete if old_file_exists
  end

  def get_S3_temporary_credentials
    bucket_name = ENV['S3_BUCKET']
    AWS.config(
      { :access_key_id => ENV["S3_ACCESS_KEY_ID"], 
        :secret_access_key => ENV["S3_SECRET_ACCESS_KEY"], 
        :session_token => nil
      })
    sts = AWS::STS.new
    session = sts.new_session(:duration => 15*60)
    return session.credentials
  end

end
