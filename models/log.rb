# encoding: utf-8

class Log
  include DataMapper::Resource

  property :id, Serial
  property :cat, String
  property :body, Text
  property :created, DateTime
  property :err, Boolean, :default  => true

  def to_json
  	body_json = JSON.parse(body) rescue body
  	{
  		id: id,
  		cat: cat,
  		body: body_json,
  		created: created
  	}
  end

end