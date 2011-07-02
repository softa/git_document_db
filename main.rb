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
    document.to_json
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

get '/documents/:id/version/:commit_id' do |id, commit_id|
  # TODO return the version's JSON
end

post '/documents/:id/fork' do |id|
  # TODO return the new document
end

put '/documents/:id/merge/:from_id' do |id, from_id|
  # TODO merge and return the merged document if it was OK
  # TODO return 409 (Conflict) if it wasn't OK
end

get '/documents/:id/pending_merges' do |id|
  # TODO return the pending_merges object as JSON
end

put '/documents/:id/resolve_conflicts/:from_id' do |id, from_id|
  # TODO resolve the conflicts and return the new document if it was OK
  # TODO return 409 (Conflict) if it wasn't OK
end
