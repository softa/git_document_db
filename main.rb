require 'sinatra'
require './document.rb'

get '/documents/:id' do |id|
  document = Document.find id
  return not_found unless document
  document.to_json
end

post '/documents' do
  document = Document.create params
  document.to_json
end

delete '/documents/:id' do |id|
  document = Document.find id
  document.destroy
end
