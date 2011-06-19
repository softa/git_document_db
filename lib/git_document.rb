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
        create_attribute :id, :read_only => !@new_record
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
      return false if attributes[name.to_s]
      raise GitDocument::Errors::InvalidAttributeName if self.class.method_defined?(name.to_sym) and name.to_sym != :id
      default = options[:default]
      value = options[:value]
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
        @attributes[name.to_s] = (value || default)
      else
        self.class_eval <<-EOF
          def #{name}=(value)
            #{name}_will_change! unless attributes['#{name}'] == value
            attributes['#{name}'] = value
          end
        EOF
        self.send("#{name}=".to_sym, (value || default))
      end
      return true
    end
    
    def remove_attribute(name)
      raise GitDocument::Errors::InvalidAttribute unless attributes.keys.include?(name.to_s)
      raise GitDocument::Errors::InvalidAttribute if name.to_s == 'id'
      @attributes[name.to_s] = nil
      read_only_undef = "undef #{name}=" if self.singleton_methods.include? "#{name}="
      self.instance_eval <<-EOF
        undef #{name}
        undef #{name}_changed?
        undef #{name}_change
        undef #{name}_was
        undef #{name}_will_change!
        undef reset_#{name}!
        #{ read_only_undef }
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
          # TODO save
        elsif self.changed?
          raise GitDocument::Errors::NotFound unless File.directory?(path)
          repo = Grit::Repo.new(path)
          # TODO save
        end
        
        if self.singleton_methods.include? 'id='
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
      # TODO remove all attributes (and their accessor methods) except id
      attributes.keys.each do |attribute|
        remove_attribute(attribute) unless attribute.to_sym == :id
      end
      args = self.class.load(self.id)
      args.each do |attribute, value|
        if create_attribute(attribute)
          self.send("#{key}=".to_sym, value)
        end
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
    
    private
    
    def attributes
      @attributes ||= {}
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
      
      def load(id)
        path = self.path id
        raise GitDocument::Errors::NotFound unless File.directory?(path)
        repo = Grit::Repo.new(path)
        attributes = {}
        # TODO load attributes from files
        attributes
      end

      def find(id)
        attributes = self.load(id).merge(:id => id)
        document = self.new(attributes, false)
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
