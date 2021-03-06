require 'sinatra'
require 'memcached'
$cache = Memcached.new("localhost:11211")

require File.join(File.dirname(__FILE__), 'document')
Document.root_path = File.join(File.dirname(File.expand_path(__FILE__)), 'db', Sinatra::Application.environment.to_s)

class App < Sinatra::Application
  set :server, %w[unicorn]

  if File.exists?('credentials.yml') and settings.environment != :test
    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      [username, password] == YAML::load(File.open 'credentials.yml')
    end
  end

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
      document = $cache.get("document_#{id}")
    rescue Memcached::NotFound
      begin
        document = Document.find id
        $cache.set "document_#{id}", document.to_json
        document.to_json
      rescue GitDocument::Errors::NotFound
        not_found
      end
    end
  end

  post '/documents' do
    return 400 unless attributes = json_attributes
    if attributes["id"]
      begin
        document = Document.create! attributes
        $cache.set "document_#{id}", document.to_json
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
      $cache.set "document_#{id}", document.to_json
      document.to_json
    rescue
      not_found
    end
  end

  delete '/documents/:id' do |id|
    begin
      document = Document.find id
      document.destroy
      $cache.delete("document_#{id}")
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
    attributes = json_attributes || {}
    begin
      document = Document.find id
      if attributes["user_id"]
        document.create_attribute :user_id
        document.user_id = attributes["user_id"]
      end
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
      if attributes["user_id"]
        document.create_attribute :user_id
        document.user_id = attributes["user_id"]
      end
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

  get '/documents/:id/merge_needed/:from_id' do |id, from_id|
    begin
      document = Document.find id
      document.merge_needed?(from_id).to_json
    rescue
      not_found
    end
  end
end
