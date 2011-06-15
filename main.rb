require 'fileutils'
require 'grit'
require 'json'
require 'sinatra'
include Grit

get '/:user/:repo/info' do |user, repo|
  dir = "repos/#{user}/#{repo}.git"
  if File.directory?(dir)
    repo = Repo.new(dir)
    repo.to_json
  else
    not_found
  end
end

get '/:user/:repo/create' do |user, repo|
  dir = "repos/#{user}/#{repo}.git"
  FileUtils.mkdir_p dir
  repo = Repo.init_bare(dir)
end
