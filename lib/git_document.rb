require 'active_model'
require 'fileutils'
require 'grit'
require 'json'

module GitDocument
  
  module Errors
    class NotFound < StandardError
    end
    class NotSaved < StandardError
    end
    class InvalidAttributeName < StandardError
    end
    class InvalidAttribute < StandardError
    end
  end
  
  module Document
    
    def self.included(base)
      base.class_eval do
         
        extend ActiveModel::Callbacks
        extend ActiveModel::Naming
        include ActiveModel::AttributeMethods
        include ActiveModel::Dirty
        include ActiveModel::Validations
        include ActiveModel::Observing
        include ActiveModel::Translation

        define_model_callbacks :initialize, :only => :after
        define_model_callbacks :save, :destroy

        validates_presence_of :id
        validates_format_of :id, :with => /^[^\/?*:;{}\\]+$/, :message => "must be a valid file name"
        
      end

      base.extend(ClassMethods)
    end
    
    def initialize(args = {}, new_record = true)
      _run_initialize_callbacks do
        @new_record = new_record
        @errors = ActiveModel::Errors.new(self)
        create_attribute :id, :read_only => !@new_record, :value => (args[:id] || args['id'])
        args.each do |attribute, value|
          create_attribute attribute, :value => value
        end
        @previously_changed = changes
        @changed_attributes.clear
      end
    end
    
    def errors
      @errors
    end
    
    def create_attribute(name, options = {})
      return false if attributes.has_key?(name.to_s)
      raise GitDocument::Errors::InvalidAttributeName if self.respond_to?(name.to_s) and name.to_sym != :id
      default = options[:default]
      value = options[:value]
      unless value.nil?
        apply_value = value
      else
        apply_value = default
      end
      self.class_eval <<-EOF
        def #{name}
          unless attributes['#{name}'].nil?
            attributes['#{name}']
          else
            #{default.inspect}
          end
        end
        def #{name}_changed?
          attribute_changed?(:#{name})
        end
        def #{name}_change
          attribute_change(:#{name})
        end
        def #{name}_was
          attribute_was(:#{name})
        end
        def #{name}_will_change!
          attribute_will_change!(:#{name})
        end
        def reset_#{name}!
          reset_attribute!(:#{name})
        end
      EOF
      if options[:read_only]
        @attributes[name.to_s] = apply_value
      else
        self.class_eval <<-EOF
          def #{name}=(value)
            #{name}_will_change! unless attributes['#{name}'] == value
            @attributes['#{name}'] = value
          end
        EOF
        self.send("#{name}=".to_sym, apply_value)
      end
      return true
    end
    
    def remove_attribute(name)
      raise GitDocument::Errors::InvalidAttribute unless attributes.has_key?(name.to_s)
      raise GitDocument::Errors::InvalidAttribute if name.to_s == 'id'
      @attributes.delete(name.to_s)
      undef_id = "undef #{name}=" if self.respond_to? "#{name}="
      self.instance_eval <<-EOF
        undef #{name}
        undef #{name}_changed?
        undef #{name}_change
        undef #{name}_was
        undef #{name}_will_change!
        undef reset_#{name}!
        #{ undef_id }
      EOF
    end
          
    def to_model
      self
    end

    def to_key
      id ? [id] : nil
    end

    def to_param
      id && id.to_s
    end
    
    def new_record?
      @new_record || false
    end
      
    def save
      _run_save_callbacks do

        return false unless self.valid?
        
        if new_record?
          if File.directory?(path)
            errors.add :id, "already exists"
            return false
          end
          FileUtils.mkdir_p path
          repo = Grit::Repo.init(path)
          commit_message = "Creating document ##{self.id}"
        elsif self.changed?
          raise GitDocument::Errors::NotFound unless File.directory?(path)
          repo = Grit::Repo.new(path)
          commit_message = "Updating document ##{self.id}"
        end
        
        if new_record? or self.changed?
          index = repo.index
          attributes.each do |name, value|
            add_attribute_to_index index, name, value
          end
          parents = repo.commit_count > 0 ? [repo.log.first.id] : nil
          my_commit = index.commit(commit_message, parents)
          repo.commit(my_commit)
        end
        
        if self.respond_to? 'id='
          self.instance_eval { undef id= }
        end
        
        @new_record = false
        @previously_changed = changes
        @changed_attributes.clear
        true
        
      end
    end

    def save!
      save || raise(GitDocument::Errors::NotSaved)
    end
    
    def reload
      attributes.keys.each do |attribute|
        remove_attribute(attribute) unless attribute.to_sym == :id
      end
      args = self.class.load(self.id)
      args.each do |attribute, value|
        create_attribute attribute, :value => value
      end
    end

    def destroy
      _run_destroy_callbacks do
        FileUtils.rm_rf(path)
      end
    end

    def path
      self.class.path id
    end

    def to_s
      "#<#{self.class.name}:#{__id__} id=#{id}, attributes=#{attributes.inspect}>"
    end
        
    def to_json
      attributes.to_json
    end
    
    def history
      return nil if new_record?
      raise GitDocument::Errors::NotFound unless File.directory?(path)
      repo = Grit::Repo.new(path)
      repo.log.map &:id
    end
    
    def version(commit_id)
      self.class.find(self.id, commit_id)
    end
    
    private
    
    def attributes
      @attributes ||= {}
    end

    def add_attribute_to_index(index, name, value, parent = nil)
      if value.is_a? Hash
        new_parent = name
        new_parent = "#{parent}/#{new_parent}" unless parent.nil?
        value.each do |new_name, new_value|
          add_attribute_to_index index, new_name, new_value, new_parent
        end
      else
        name = "#{parent}/#{name}" unless parent.nil?
        index.add(name, value.to_json)
      end
    end
    
    module ClassMethods

      def root_path
        @@root_path if defined?(@@root_path)
      end
      
      def root_path=(path)
        @@root_path = path
      end
      
      def path(id)
        "#{root_path}/#{id}.git"
      end
      
      def load(id, commit_id = nil)
        # Workaround to fix JSON.parse incapacity of parsing root objects that are not Array or Hashes
        def jparse(str)
          return JSON.parse(str) if str =~ /\A\s*[{\[]/
          JSON.parse("[#{str}]")[0]
        end
        path = self.path id
        raise GitDocument::Errors::NotFound unless File.directory?(path)
        repo = Grit::Repo.new(path)
        attributes = {}
        if commit_id
          commit = repo.commit(commit_id)
        else
          commit = repo.log.first
        end
        load_tree(commit.tree, attributes)
        attributes
      end

      def find(id, commit_id = nil)
        attributes = self.load(id, commit_id).merge(:id => id)
        self.new(attributes, false)
      end

      def create(args = {})
        document = self.new args
        document.save
        document
      end

      def create!(args = {})
        document = self.new args
        document.save!
        document
      end
      
      private
      
      def load_tree(tree, attributes)
        tree.contents.each do |git_object|
          if git_object.is_a? Grit::Tree
            attributes[git_object.name.to_sym] = {}
            load_tree(git_object, attributes[git_object.name.to_sym])
          else
            attributes[git_object.name.to_sym] = jparse(git_object.data)
          end
        end
      end

    end

  end
end
