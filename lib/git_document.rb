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
  end
  
  module Document
    
    attr_reader :errors

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
        
        # TODO Add validation to verify if id is a valid filename
        # TODO Validate uniqueness of id
        
      end

      base.extend(ClassMethods)
    end
    
    def initialize(args = {}, new_record = true)
      _run_initialize_callbacks do
        @new_record = new_record
        @errors = ActiveModel::Errors.new(self)
        attribute :id
        args.each do |key, value|
          if attribute(key) or key.to_sym == :id
            self.send("#{key}=".to_sym, value)
          end
        end
        @previously_changed = changes
        @changed_attributes.clear
      end
    end
    
    def attributes
      @attributes ||= {}
    end

    def attribute(name, options = {})
      return if self.class.method_defined?(name.to_sym) and name.to_sym != :id
      default = options[:default]
      self.class_eval <<-EOF
        def #{name}
          attributes['#{name}'] || #{default.inspect}
        end
        def #{name}_changed?
          attribute_changed?(:#{name})
        end
        def #{name}_change
          attribute_change(:#{name})
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
        def #{name}=(value)
          #{name}_will_change! unless attributes['#{name}'] == value
          attributes['#{name}'] = value
        end
      EOF
      return true
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
        # TODO implement validations and verify self.valid? before saving
        # TODO add errors whenever a validation fail
        return false unless id
        
        if new_record?
          FileUtils.mkdir_p path
          repo = Grit::Repo.init_bare(path)
          # TODO save
        elsif self.changed?
          raise GitDocument::Errors::NotFound unless File.directory?(path)
          repo = Grit::Repo.new(path)
          # TODO save
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
      # TODO reload attributes
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

    module ClassMethods

      def root_path
        @@root_path
      end
      
      def root_path=(path)
        @@root_path = path
      end
      
      def path(id)
        "#{root_path}/#{id}.git"
      end

      def find(id)
        path = self.path id
        raise GitDocument::Errors::NotFound unless File.directory?(path)
        repo = Grit::Repo.new(path)
        # TODO load attributes from files
        attributes = {}
        document = self.new(attributes.merge(:id => id), false)
      end

      def create(args = {})
        document = self.new args
        document.save
      end

      def create!(args = {})
        document = self.new args
        document.save!
      end

    end

  end
end
