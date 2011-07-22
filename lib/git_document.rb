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
    class AlreadyExists < StandardError
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
        
        attr_reader :commit_id
        
      end

      base.extend(ClassMethods)
    end
    
    def initialize(args = {}, new_record = true)
      _run_initialize_callbacks do
        @new_record = new_record
        @errors = ActiveModel::Errors.new(self)
        create_attribute :id, :read_only => !@new_record, :value => (args[:id] || args['id'])
        args.each do |name, value|
          create_attribute name, :value => value
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
      raise GitDocument::Errors::InvalidAttributeName if name.to_sym == :attribute
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

    def update_attributes(attributes)
      self.attributes = attributes
      self.save
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
          repo = Grit::Repo.init_bare(path)
          commit_message = "Creating document ##{self.id}"
        elsif self.changed?
          raise GitDocument::Errors::NotFound unless File.directory?(path)
          repo = Grit::Repo.new(path)
          commit_message = "Updating document ##{self.id}"
        end
        
        if new_record? or self.changed?
          index = repo.index
          attributes.each do |name, value|
            unless name.to_s == 'id' or name.to_s == 'user_id'
              add_attribute_to_index index, name, value
            end
          end
          parents = repo.commit_count > 0 ? [repo.log.first.id] : nil
          commit = index.commit(commit_message, parents, self.actor)
          @commit_id = commit
          repo.commit(commit)
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
        remove_attribute(attribute) unless attribute.to_sym == :id or attribute.to_sym == :user_id
      end
      args = self.class.load(self.id)
      args.each do |name, value|
        create_attribute name, :value => value
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

    def merge_path(from_id)
      self.class.merge_path id, from_id
    end

    def diff_path(from_id)
      self.class.diff_path id, from_id
    end

    def merges_path
      self.class.merges_path id
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
      repo.log.map do |commit|
        {
          :commit_id => commit.id,
          :user_id => commit.author.name,
          :timestamp => commit.authored_date
        }
      end
    end
    
    def version(commit_id)
      self.class.find(self.id, commit_id)
    end
    
    def create_fork(new_id)
      raise GitDocument::Errors::NotFound unless File.directory?(path)
      new_path = self.class.path(new_id)
      raise GitDocument::Errors::AlreadyExists if File.directory?(new_path)
      repo = Grit::Repo.new(path)
      repo.fork_bare(new_path)
      self.class.find new_id
    end
    
    def merge!(from_id)
      raise GitDocument::Errors::NotFound unless File.directory?(path)
      raise GitDocument::Errors::NotFound unless File.directory?(self.class.path(from_id))
      repo = Grit::Repo.new(path)
      merge_path = self.merge_path(from_id)
      FileUtils.rm_rf(merge_path)
      repo.git.clone({}, path, merge_path)
      Dir.chdir(merge_path) do
        merge_repo = Grit::Repo.new('.')
        merge_repo.config["user.name"] = self.actor.name
        merge_repo.config["user.email"] = self.actor.email
        merge_repo.git.remote({}, "add", "merge", self.class.path(from_id))
        merge_repo.git.pull({}, "merge", "master")
        no_conflicts = self.class.no_conflicts?(merge_repo)
        if no_conflicts
          FileUtils.rm_rf(path)
          repo.git.clone({ :bare => true }, "#{merge_path}/.git", path)
          FileUtils.rm_rf(merge_path)
        end
        no_conflicts
      end
    end
    
    def pending_merges
      FileUtils.mkdir_p self.merges_path
      dir = Dir.new self.merges_path
      merges = []
      dir.each do |from_id|
        next if [".", ".."].include? from_id
        merges << pending_merge(from_id)
      end
      merges
    end
    
    def resolve_conflicts!(from_id, attributes)
      merge_path = self.merge_path(from_id)
      raise GitDocument::Errors::NotFound unless File.directory?(merge_path)
      repo = Grit::Repo.new(merge_path)
      attributes.each do |name, value|
        unless name.to_s == 'id' or name.to_s == 'user_id'
          add_file_to_repo repo, name, value
        end
      end
      message = "Resolving conflicts from merge with document ##{from_id}"
      repo.git.commit({}, '-m', message, "--author=#{self.actor}")
      no_conflicts = self.class.no_conflicts?(repo)
      if no_conflicts
        FileUtils.rm_rf(path)
        repo.git.clone({ :bare => true }, "#{merge_path}/.git", path)
        FileUtils.rm_rf(merge_path)
      end
      no_conflicts
    end
    
    def actor
      if self.respond_to? :user_id
        user = user_id
      else
        user = "anonymous"
      end
      Grit::Actor.from_string("#{user} <#{user}@gitdocument.rb>")
    end
    
    def merge_needed?(from_id)
      raise GitDocument::Errors::NotFound unless File.directory?(path)
      raise GitDocument::Errors::NotFound unless File.directory?(self.class.path(from_id))
      repo = Grit::Repo.new(path)
      from_repo = Grit::Repo.new(self.class.path(from_id))
      repo.commit_deltas_from(from_repo).size > 0
    end

    private
    
    def pending_merge(from_id)
      raise GitDocument::Errors::NotFound unless File.directory?(self.merge_path(from_id))
      merge_repo = Grit::Repo.new(self.merge_path(from_id))
      files = []
      merge_repo.status.files.map{ |file| file[1] }.each do |file|
        next unless file.type == "M"
        files << file.path unless files.include? file.path
      end
      merge = { 'from_id' => from_id }
      attributes = {}
      files.each do |file|
        content = File.open("#{self.merge_path(from_id)}/#{file}", 'rb') { |f| f.read }
        file_merge = Grit::Merge.new(content)
        attribute = {
          'conflicts' => file_merge.conflicts,
          'sections' => file_merge.sections,
          'text' => file_merge.text
        }
        # Weird code to convert a path like to foo/bar/foo to
        # A Hash tree like { :foo => { :bar => { :foo => attribute } } }
        # Couldn't think of anything easier, but I'm sure there must be a better way
        levels = file.split('/')
        levels.map! { |level| "\"#{level}\"" }
        attribute_json = levels.join(':{')
        attribute_json = attribute_json + ':' + attribute.to_json
        (1...levels.size).each { attribute_json = attribute_json + '}' }
        attribute_json = "{#{attribute_json}}"
        attribute = self.class.jparse(attribute_json)
        attributes.merge!(attribute)
      end
      merge['attributes'] = attributes
      merge
    end
    
    def attributes
      @attributes ||= {}
    end

    def attributes=(new_attributes)
      new_attributes.each do |name, value|
        self.create_attribute(name) unless attributes.has_key?(name)
        self.send(name.to_s + '=', value) unless name.to_sym == :id
      end
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
        index.add(name, value.to_json.gsub("\\n", "\n"))
      end
    end
    
    def add_file_to_repo(repo, name, value, parent = nil)
      if value.is_a? Hash
        new_parent = name
        new_parent = "#{parent}/#{new_parent}" unless parent.nil?
        value.each do |new_name, new_value|
          add_file_to_repo repo, new_name, new_value, new_parent
        end
      else
        name = "#{parent}/#{name}" unless parent.nil?
        value = value.to_json.gsub("\\n", "\n")
        repo_path = repo.path.gsub('/.git', '')
        Dir.chdir(repo_path) do
          File.open("#{name}", 'w') do |file|
            file.write(value)
          end
          repo.git.add({}, name)
        end
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
        "#{root_path}/documents/#{id}.git"
      end
      
      def merge_path(id, from_id)
        "#{root_path}/merges/#{id}/#{from_id}"
      end
      
      def diff_path(id, from_id)
        "#{root_path}/diffs/#{id}/#{from_id}"
      end
      
      def merges_path(id)
        "#{root_path}/merges/#{id}"
      end

      def load(id, commit_id = nil)
        path = self.path id
        raise GitDocument::Errors::NotFound unless File.directory?(path)
        repo = Grit::Repo.new(path)
        attributes = {}
        if commit_id
          commit = repo.commit(commit_id)
        else
          commit = repo.log.first
        end
        @commit_id = commit.id
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
      
      # Workaround to fix JSON.parse incapacity of parsing root objects that are not Array or Hashes
      def jparse(str)
        return JSON.parse(str) if str =~ /\A\s*[{\[]/
        begin
          JSON.parse("[#{str}]")[0]
        rescue
          puts "AKIIII: [#{str}]"
        end
      end
      
      def no_conflicts?(repo)
        repo.status.files.map{ |file| file[1] }.each do |file|
          return false if file.type == "M"
        end
        true
      end
      
      private
      
      def load_tree(tree, attributes)
        tree.contents.each do |git_object|
          if git_object.is_a? Grit::Tree
            attributes[git_object.name.to_sym] = {}
            load_tree(git_object, attributes[git_object.name.to_sym])
          else
            attributes[git_object.name.to_sym] = jparse(git_object.data.gsub("\n", "\\n"))
          end
        end
      end

    end

  end
end
