require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'git_document')

describe "GitDocument::Document" do
  
  before(:each) do
    class Document
      include GitDocument::Document
    end
    Document.root_path = File.join(File.dirname(__FILE__), '..', 'documents', 'test')
  end

  it "should initialize" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.id.should == "foo"
    document.foo.should == "bar"
  end

  it "should set the attributes property on initialization" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.attributes['id'].should == "foo"
    document.attributes['foo'].should == "bar"
  end

  it "should have included GitDocument::Document" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.class.included_modules.include?(GitDocument::Document).should == true
  end

  it "should run after initialize callback" do
    class Document
      attr_accessor :initialized
      after_initialize :set_initialized
      def set_initialized
        @initialized = true
      end
    end
    document = Document.new :id => 'foo', :foo => 'bar'
    document.initialized.should == true
  end

  it "should set new record properly on initialization" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.new_record?.should == true
    document = Document.new({:id => 'foo', :foo => 'bar'}, true)
    document.new_record?.should == true
    document = Document.new({:id => 'foo', :foo => 'bar'}, false)
    document.new_record?.should == false
  end
  
  # TODO try to make ActiveModel::Dirty work with dynamic attributes
  it "should track changes to the attributes"# do
=begin
    document = Document.new :id => 'foo', :foo => 'bar'
    document.changed?.should == false
    document.foo = "foo bar"
    document.changed?.should == true
    document.id_changed?.should == false
    document.foo_changed?.should == true
    document.changes.should == { 'foo' => ['bar', 'foo bar'] }
    document.id = "bar"
    document.id_changed?.should == true
    document.changes.should == { 'foo' => ['bar', 'foo bar'], 'id' => ['foo', 'bar'] }
    document.save
    document.changed?.should == false
=end
  
  it "should have a read only id unless it is a new record"

  it "should create new attributes dinamically" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.attribute :bar
    document.bar = "foo"
    document.attributes['bar'].should == "foo"
  end
  
  it "should convert to model" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.to_model.should == document
  end
  
  it "should convert to key" do
    document = Document.new :id => nil, :foo => 'bar'
    document.to_key.should == nil
    document = Document.new :id => 'foo', :foo => 'bar'
    document.to_key.should == ['foo']
  end
  
  it "should convert to param" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.to_param.should == 'foo'
  end
  
  it "should convert to string" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.to_s.should == "#<Document:#{document.__id__} id=foo, attributes={\"id\"=>\"foo\", \"foo\"=>\"bar\"}>"
  end
  
  it "should convert to JSON" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.to_json.should == '{"id":"foo","foo":"bar"}'
  end
  
  it "should not be new record after saving" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.new_record?.should == true
    document.save
    document.new_record?.should == false
  end
  
  it "should save a new record" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.save.should == true
    document.reload
    document.id.should == 'foo'
    document.foo.should == 'bar'
  end
  
  it "should save an existing record"
  
  it "should not save without an id" do
    document = Document.new
    document.save.should == false
  end
  
  it "should raise an error when using save! and not saving" do
    document = Document.new
    lambda {document.save!}.should raise_error(GitDocument::Errors::NotSaved)
  end
  
  it "should reload the attributes"
  it "should destroy a document"
  
  it "should return the path to the repository" do
    document = Document.new :id => 'foo'
    document.path.should == "#{Document.root_path}/foo.git"
  end
  
  it "should have a root path" do
    Document.root_path = "abc"
    Document.root_path.should == "abc"
  end
  
  it "should return the path for an id" do
    Document.root_path = "abc"
    Document.path("foo").should == "abc/foo.git"
  end
  
  it "should find a document and retrieve its attributes" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.save.should == true
    document = Document.find 'foo'
    document.id.should == 'foo'
    document.foo.should == 'bar'
  end
  
  it "should create a document"
  
  it "should raise an error when using create! and not creating" do
    lambda {Document.create!}.should raise_error(GitDocument::Errors::NotSaved)
  end
  
end
