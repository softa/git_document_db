require 'sinatra'

require File.join(File.dirname(__FILE__), 'document')
Document.root_path = File.join(File.dirname(__FILE__), 'db', Sinatra::Application.environment.to_s)

def json_attributes
  begin
    JSON.parse(request.body.read.to_s)
  rescue
    false
  end
end

before do
  content_type 'application/json'
end

get '/documents/:id' do |id|
  begin
    document = Document.find id
    document.to_json
  #rescue
  #  not_found
  end
end

post '/documents' do
  return 400 unless attributes = json_attributes
  if attributes["id"]
    begin
      document = Document.create! attributes
      document.to_json
    rescue
      409
    end
  else
    406
  end
end

put '/documents/:id' do |id|
  return 400 unless attributes = json_attributes
  begin
    document = Document.find id
    document.update_attributes(attributes)
    document.to_json
  rescue
    not_found
  end
end

delete '/documents/:id' do |id|
  begin
    document = Document.find id
    document.destroy
    document.to_json
  rescue
    not_found
  end
end

get '/documents/:id/history' do |id|
  begin
    document = Document.find id
    document.history.to_json
  rescue
    not_found
  end
end

get '/documents/:id/version/:commit_id' do |id, commit_id|
  begin
    document = Document.find id
    version = document.version(commit_id)
    version.to_json
  rescue
    not_found
  end
end

post '/documents/:id/fork/:new_id' do |id, new_id|
  begin
    document = Document.find id
    fork = document.create_fork(new_id)
    fork.to_json
  rescue
    not_found
  end
end

put '/documents/:id/merge/:from_id' do |id, from_id|
  begin
    document = Document.find id
    if document.merge!(from_id)
      document.reload
      document.to_json
    else
      409
    end
  rescue
    not_found
  end
end

get '/documents/:id/pending_merges' do |id|
  begin
    document = Document.find id
    document.pending_merges.to_json
  rescue
    not_found
  end
end

put '/documents/:id/resolve_conflicts/:from_id' do |id, from_id|
  return 400 unless attributes = json_attributes
  begin
    document = Document.find id
    if document.resolve_conflicts!(from_id, attributes)
      document.reload
      document.to_json
    else
      409
    end
  rescue
    not_found
  end
end
