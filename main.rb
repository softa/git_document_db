require 'sinatra'
require File.dirname(__FILE__) + 'document'

get '/documents/:id' do |id|
  document = Document.find id
  document.to_json
rescue
  not_found
end

post '/documents' do
  document = Document.create params
  document.to_json
end

delete '/documents/:id' do |id|
  document = Document.find id
  document.destroy
end
