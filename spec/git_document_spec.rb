require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '..', 'lib', 'git_document')

describe "GitDocument::Document" do

  before(:each) do
    FileUtils.rm_rf(Document.root_path)
  end

  it "should initialize and set attributes" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.id.should == "foo"
    document.foo.should == "bar"
  end

  it "should not access the attributes hash directly" do
    document = Document.new :id => 'foo', :foo => 'bar'
    lambda{ document.attributes['id'] }.should raise_error(NoMethodError)
    lambda{ document.attributes['bar'] }.should raise_error(NoMethodError)
  end

  it "should have included GitDocument::Document" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.class.included_modules.include?(GitDocument::Document).should == true
  end

  it "should run after initialize callback" do
    class MyDocument
      include GitDocument::Document
      attr_accessor :initialized
      after_initialize :set_initialized
      def set_initialized
        @initialized = true
      end
    end
    document = MyDocument.new :id => 'foo', :foo => 'bar'
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
  
  it "should track changes to the attributes" do
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
  end
  
  it "should track changes to dynamicly created attributes as well" do
    document = Document.new :id => 'foo'
    document.changed?.should == false
    document.create_attribute :foo
    document.foo = "foo bar"
    document.changed?.should == true
    document.foo_changed?.should == true
    document.changes.should == { 'foo' => [nil, 'foo bar'] }
    document.save
    document.changed?.should == false
  end

  it "should have a read only id unless it is a new record" do
    document = Document.new :id => 'foo'
    document.new_record?.should == true
    document.id.should == 'foo'
    document.id = 'bar'
    document.id.should == 'bar'
    document.save
    document.new_record?.should == false
    document.id.should == 'bar'
    lambda{ document.id = 'foo' }.should raise_error(NoMethodError)
    lambda{ document.attributes['id'] = 'foo' }.should raise_error(NoMethodError)
  end

  it "should create new attributes dynamically" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.create_attribute :bar
    document.bar = "foo"
  end
  
  it "should create read only attributes dynamically" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.create_attribute :bar, :read_only => true
    lambda{ document.bar }.should_not raise_error(NoMethodError)
    lambda{ document.bar = 'foo' }.should raise_error(NoMethodError)
  end
  
  it "should not create attributes that are pre-existing methods and raise an error" do
    document = Document.new :id => 'foo', :foo => 'bar'
    lambda{ document.create_attribute :send }.should raise_error(GitDocument::Errors::InvalidAttributeName)
    lambda{ document.create_attribute :attribute }.should raise_error(GitDocument::Errors::InvalidAttributeName)
  end
  
  it "should remove a dymamic attribute" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.remove_attribute :foo
    lambda{ document.foo }.should raise_error(NoMethodError)
  end
  
  it "should not remove a dymamic attribute that doesn't exist" do
    document = Document.new :id => 'foo'
    lambda{ document.remove_attribute :foo }.should raise_error(GitDocument::Errors::InvalidAttribute)
  end
  
  it "should not remove the id attribute" do
    document = Document.new :id => 'foo'
    lambda{ document.remove_attribute :id }.should raise_error(GitDocument::Errors::InvalidAttribute)
  end
  
  it "should remove a read only attribute without problems" do
    document = Document.new :id => 'foo'
    document.create_attribute :foo, :read_only => true
    document.foo
    document.remove_attribute :foo
    lambda{ document.foo }.should raise_error(NoMethodError)
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
    commit_id = document.commit_id
    document.reload
    document.id.should == 'foo'
    document.foo.should == 'bar'
    document.commit_id.should == commit_id
  end
  
  it "should not save without an id" do
    document = Document.new
    document.save.should == false
    document.errors[:id].should == ["can't be blank", "must be a valid file name"]
  end

  it "should not save with an invalid id" do
    document = Document.new
    %w(/ ? * : ; { } \\).each do |char|
      document.id = "foo#{char}"
      document.save.should == false
      document.errors[:id].should == ["must be a valid file name"]
    end
  end

  it "should not save with a duplicate id" do
    Document.create :id => 'foo'
    document = Document.new :id => 'foo'
    document.save.should == false
    document.errors[:id].should == ["already exists"]
  end
  
  it "should save an existing record" do
    Document.create :id => 'foo', :foo => 'bar'
    document = Document.find 'foo'
    document.foo = 'foobar'
    document.save.should == true
    document.reload
    document.foo.should == 'foobar'
  end
  
  it "should save and retrieve string values" do
    d = Document.create :id => 'foo', :foo => 'bar'
    commit_id = d.commit_id
    document = Document.find 'foo'
    document.foo.should === 'bar'
    document.commit_id.should == nil
  end
  
  it "should save and retrieve numeric values" do
    Document.create :id => 'foo', :foo => 123, :bar => 456.78
    document = Document.find 'foo'
    document.foo.should === 123
    document.bar.should === 456.78
  end
  
  it "should save and retrieve boolean fields" do
    Document.create :id => 'foo', :foo => true, :bar => false
    document = Document.find 'foo'
    document.foo.should === true
    document.bar.should === false
  end
  
  it "should save and retrieve null values" do
    Document.create :id => 'foo', :foo => nil
    document = Document.find 'foo'
    document.foo.should === nil
  end
  
  it "should save and retrieve array values" do
    Document.create :id => 'foo', :foo => ["1", 2, 3.4, false, nil, ["abc", 123]]
    document = Document.find 'foo'
    document.foo.should === ["1", 2, 3.4, false, nil, ["abc", 123]]
  end
  
  it "should save nested hashes of attributes" do
    Document.create({
      :id => 'foo',
      :foo => {
        :bar => 45.99,
        :foo => true,
        :nil => nil,
        :array => ["1", "2", "3"]
      },
      :bar => {
        :foo_bar => 'bar_foo',
        :abc => {
          :foo => 123,
          :bar => 456,
          :array_of_hashes => [{ "foo" => "bar" }, { "foo" => "foobar" }]
        }
      }
    })
    document = Document.find 'foo'
    document.foo.should == { :bar => 45.99, :foo => true, :nil => nil, :array => ["1", "2", "3"] }
    document.bar.should == { :foo_bar => 'bar_foo', :abc => { :foo => 123, :bar => 456, :array_of_hashes => [{ "foo" => "bar" }, { "foo" => "foobar" }] } }
  end
  
  it "should raise an error when using save! and not saving" do
    document = Document.new
    lambda{document.save!}.should raise_error(GitDocument::Errors::NotSaved)
  end
  
  it "should reload the attributes" do
    document1 = Document.create :id => 'foo', :foo => 'bar'
    document2 = Document.find 'foo'
    document2.foo.should == 'bar'
    document1.foo = 'foobar'
    document1.save
    document2.reload
    document2.foo.should == 'foobar'
  end
  
  it "should destroy a document" do
    Document.create :id => 'foo'
    document = Document.find 'foo'
    document.destroy
    lambda{ Document.find 'foo' }.should raise_error(GitDocument::Errors::NotFound)
  end
  
  it "should return the path to the repository" do
    document = Document.new :id => 'foo'
    document.path.should == "#{Document.root_path}/documents/foo.git"
  end
  
  it "should have a root path" do
    old_path = Document.root_path
    Document.root_path = "abc"
    Document.root_path.should == "abc"
    Document.root_path = old_path
  end
  
  it "should return the path for an id" do
    old_path = Document.root_path
    Document.root_path = "abc"
    Document.path("foo").should == "abc/documents/foo.git"
    Document.root_path = old_path
  end

  it "should find a document and retrieve its attributes" do
    Document.create :id => 'foo', :foo => 'bar'
    document = Document.find 'foo'
    document.id.should == 'foo'
    document.foo.should == 'bar'
  end

  it "should not find and inexistent document" do
    lambda{ Document.find 'foo' }.should raise_error(GitDocument::Errors::NotFound)
  end
  
  it "should create a document" do
    document = Document.create :id => 'foo', :foo => 'bar'
    document.reload
    document.id.should == 'foo'
    document.foo.should == 'bar'
  end
  
  it "should raise an error when using create! and not creating" do
    lambda{Document.create!}.should raise_error(GitDocument::Errors::NotSaved)
  end

  it "should have a history with all the document's versions, in descendent order" do
    document = Document.create :id => 'foo', :foo => 'bar'
    document.history.size.should == 1
    document.foo = 'foobar'
    document.save
    document.history.size.should == 2
    document.create_attribute :bar
    document.bar = 'foo'
    document.save
    document.history.size.should == 3
    version = document.history[2]
    version[:user_id].should == "anonymous"
    version[:timestamp].is_a?(Time).should == true
    document1 = document.version(version[:commit_id])
    document1.id.should == 'foo'
    document1.foo.should == 'bar'
    version = document.history[1]
    version[:user_id].should == "anonymous"
    version[:timestamp].is_a?(Time).should == true
    document2 = document.version(version[:commit_id])
    document2.id.should == 'foo'
    document2.foo.should == 'foobar'
    version = document.history[0]
    version[:user_id].should == "anonymous"
    version[:timestamp].is_a?(Time).should == true
    document3 = document.version(version[:commit_id])
    document3.id.should == 'foo'
    document3.foo.should == 'foobar'
    document3.bar.should == 'foo'
  end
  
  it "should not have a history if the record is new" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.history.nil?.should == true
  end
  
  it "should not write to history if the document hasn't changed" do
    document = Document.create :id => 'foo', :foo => 'bar'
    document.history.size.should == 1
    document.foo = 'bar'
    document.save
    document.history.size.should == 1
  end
  
  it "should be able to fork into a new document" do
    document = Document.create :id => 'foo', :foo => 'bar'
    forked = document.create_fork 'bar'
    forked.id.should == 'bar'
    forked.foo.should == 'bar'
    forked.history.should == document.history
  end
  
  it "should not fork into an existing document" do
    Document.create :id => 'bar', :bar => 'foo'
    document = Document.create :id => 'foo', :foo => 'bar'
    lambda{ document.create_fork 'bar' }.should raise_error(GitDocument::Errors::AlreadyExists)
  end

  it "should merge another document, even with nested objects" do
    document = Document.create :id => 'foo', :foo => 'bar'
    forked = document.create_fork 'bar'
    forked.create_attribute :bar
    forked.bar = { :foo => { :bar => 'foo' } }
    forked.save
    document.merge!(forked.id).should == true
    document.reload
    document.id.should == 'foo'
    document.foo.should == 'bar'
    document.bar.should == { :foo => { :bar => 'foo' } }
  end
  
  it "should merge another document and parse conflicts, even with nested objects" do
    document = Document.create :id => 'foo', :foo => 'bar', :text => "Line1\nLine2\nLine2\nLine2\nLine2\nLine2\nLine3\nLine4"
    forked = document.create_fork 'bar'
    forked.create_attribute :bar
    forked.bar = { :foo => { :bar => 'foo' } }
    forked.text = "Line1_forked\nLine2\nLine2\nLine2\nLine2\nLine2\nLine3_forked\nLine4"
    forked.save
    document.create_attribute :bar
    document.bar = { :foo => { :bar => 'bar' } }
    document.text = "Line1_document\nLine2\nLine2\nLine2\nLine2\nLine2\nLine3_document\nLine4"
    document.save
    document.merge!(forked.id).should == false
    document.pending_merges.size.should == 1
    merge = document.pending_merges[0]
    merge['from_id'].should == forked.id
    attributes = merge['attributes']
    bar = attributes['bar']['foo']['bar']
    bar['conflicts'].should == 1
    bar['sections'].should == 1
    bar['text'].size.should == 1
    bar = bar['text'][0]
    bar['ours'].should == ["\"bar\""]
    bar['theirs'].should == ["\"foo\""]
    text = attributes['text']
    text['conflicts'].should == 2
    text['sections'].should == 4
    text['text'].size.should == 4
    text['text'][0].should == {"ours"=>["\"Line1_document"], "theirs"=>["\"Line1_forked"]}
    text['text'][1].should == {"both"=>["Line2", "Line2", "Line2", "Line2", "Line2"]}
    text['text'][2].should == {"ours"=>["Line3_document"], "theirs"=>["Line3_forked"]}
    text['text'][3].should == {"both"=>["Line4\""]}
  end
  
  it "should resolve conflicts, even with nested attributes" do
    document = Document.create :id => 'foo', :foo => { :bar => 'foo' }
    forked = document.create_fork 'bar'
    forked.foo = { :bar => 'bar' }
    forked.save
    document.foo = { :bar => 'foobar' }
    document.save
    document.merge!(forked.id).should == false
    document.pending_merges.size.should == 1
    document.resolve_conflicts!('bar', :foo => { :bar => '123' }).should == true
    document.reload
    document.pending_merges.should == []
    document.id.should == 'foo'
    document.foo.should == { :bar => '123' }
  end

  it "should not resolve conflicts unless all files are OK" do
    document = Document.create :id => 'foo', :foo => { :bar => 'foo' }, :text => "ABC"
    forked = document.create_fork 'bar'
    forked.foo = { :bar => 'bar' }
    forked.text = "CBA"
    forked.save
    document.foo = { :bar => 'foobar' }
    document.text = "BCA"
    document.save
    document.merge!(forked.id).should == false
    document.pending_merges.size.should == 1
    document.resolve_conflicts!('bar', :foo => { :bar => '123' }).should == false
    document.reload
    document.pending_merges.size.should == 1
    document.id.should == 'foo'
    document.foo.should == { :bar => 'foobar' }
    document.text.should == "BCA"
  end

  it "should update attributes, and create new attributes if necessary" do
    document = Document.create :id => 'foo', :foo => 'bar'
    document.update_attributes(:foo => 'baz', :new_attribute => 'foo')
    document.reload
    document.foo.should == 'baz'
    document.id.should == 'foo'
    document.new_attribute.should == 'foo'
  end
  
  it "should commit with a user_id, if set, and return the user on history" do
    document = Document.create :id => 'with_user', :user_id => "foo", :foo => 'bar'
    document.update_attributes :user_id => "bar", :foo => 'baz'
    document.history.size.should == 2
    document.history[1][:user_id].should == "foo"
    document.history[0][:user_id].should == "bar"
  end

  it "should commit with a user_id when resolving conflicts as well", :now => true do
    document = Document.create :id => 'foo', :user_id => 1, :foo => { :bar => 'foo' }
    forked = document.create_fork 'bar'
    forked.update_attributes :user_id => 2, :foo => { :bar => 'bar' }
    document.update_attributes :foo => { :bar => 'foobar' }
    document.merge!(forked.id).should == false
    document.pending_merges.size.should == 1
    document.resolve_conflicts!('bar', :foo => { :bar => '123' }).should == true
    document.reload
    document.history.size.should == 4
    document.history[0][:user_id].should == "1"
    document.history[1][:user_id].should == "1"
    document.history[2][:user_id].should == "2"
    document.history[3][:user_id].should == "1"
  end

end
