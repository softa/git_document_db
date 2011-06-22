require 'sinatra'

require File.join(File.dirname(__FILE__), 'document')
Document.root_path = File.join(File.dirname(__FILE__), 'db', Sinatra::Application.environment.to_s)

before do
  content_type 'application/json'
end

get '/documents/:id' do |id|
  begin
    document = Document.find id
    document.to_json
  rescue
    not_found
  end
end

post '/documents' do
  if params[:id]
    document = Document.create params
    document.to_json
  else
    406
  end
end

put '/documents/:id' do |id|
  begin
    document = Document.find id
    document.update_attributes(params)
    document.save
  rescue
    not_found
  end
end

delete '/documents/:id' do |id|
  begin
    document = Document.find id
    document.destroy
    nil
  rescue
    not_found
  end
end

get '/documents/:id/history' do |id|
  document = Document.find id
  document.history.to_json
end
