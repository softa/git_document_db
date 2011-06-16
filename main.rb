require 'sinatra'

require File.join(File.dirname(__FILE__), 'document')
Document.root_path = File.join(File.dirname(__FILE__), '..', 'documents', Sinatra::Application.environment.to_s)

get '/documents/:id' do |id|
  begin
    document = Document.find id
    document.to_json
  rescue
    not_found
  end
end

post '/documents' do
  document = Document.create params
  document.to_json
end

delete '/documents/:id' do |id|
  document = Document.find id
  document.destroy
end
