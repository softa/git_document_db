require 'fileutils'
require 'grit'
require 'json'
require 'sinatra'
include Grit

def doc_path id
  "documents/#{id}.git"
end

get '/documents/:id' do |id|
  path = doc_path id
  if File.directory?(path)
    repo = Repo.new(path)
    repo.to_json
  else
    not_found
  end
end

post '/documents' do
  path = doc_path id
  FileUtils.mkdir_p path
  repo = Repo.init_bare(path)
end

delete '/documents/:id' do |id|
  FileUtils.rm_rf(doc_path id)
end
