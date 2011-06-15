require 'fileutils'
require 'grit'
require 'json'

class RepoNotFound < StandardError
end

class Document

  include Grit
  
  attr_accessor :id, :repo, :attributes

  def initialize id
    self.id = id
    self.attributes = {}
    raise RepoNotFound unless File.directory?(path)
    self.repo = Repo.new(path)
  end
  
  def destroy
    FileUtils.rm_rf(path)
  end
  
  def to_json
    self.attributes.merge({:id => self.id}).to_json
  end

  def path
    Document.path id
  end

  def self.path id
    "documents/#{id}.git"
  end

  def self.find id
    Document.new id
  rescue
    return nil
  end
  
  def self.create params
    id = params[:id]
    path = self.path(id)
    FileUtils.mkdir_p path
    repo = Repo.init_bare(path)
    # TODO assign attributes, removing the id ;)
    Document.new id
  end

end
