require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Main" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  it "should create a document" do
    post '/documents', {:id => 'foobar'}
    last_response.should be_ok
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foobar"}'
  end
  
  it "should not create a document without a id"# do
  #   post '/documents'
  #   last_response.status.should == '404'
  # end

  it "should create a document with attributes"

  it "should delete a document"
  
  it "should update a document"
end
