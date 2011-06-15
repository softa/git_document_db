require 'fileutils'
require 'grit'
require 'json'
require 'sinatra'
include Grit

def dir
  "documents/:id.git"
end

get '/documents/:id' do |id|
  dir = "documents/#{id}.git"
  if File.directory?(dir)
    repo = Repo.new(dir)
    repo.to_json
  else
    not_found
  end
end

post '/documents' do
  dir = "documents/#{repo}.git"
  FileUtils.mkdir_p dir
  repo = Repo.init_bare(dir)
end

delete '/documents/:id' do |id|
  FileUtils.rm_rf
end
