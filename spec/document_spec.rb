require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Document" do
  
  it "should have included GitDocument::Document" do
    document = Document.new :id => 'foo', :foo => 'bar'
    document.class.included_modules.include?(GitDocument::Document).should == true
  end
  
end
