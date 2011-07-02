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
  
  it "should not create a document without an id" do
    post '/documents'
    last_response.status.should == 406
  end

  it "should create a document with attributes"  do
    data = {:id => "foo", :foo => "bar", :baz => 'content'}
    post '/documents', data
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == data.to_json
  end

  it "should delete a document" do
    post '/documents', {:id => 'foobar'}
    delete '/documents/foobar'
    last_response.status.should == 200
  end
  
  it "should receive 404 response when trying to delete a document that doesn't exists" do
    delete '/documents/non_existant_document'
    last_response.status.should == 404
    last_response.body.should == ''
  end


  it "should update a document" do
    post '/documents', {:id => 'foobar', :foo => 'bar'}

    get '/documents/foobar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foobar","foo":"bar"}'

    put '/documents/foobar', {:foo => 'baz'}
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foobar","foo":"baz"}'
    
    get '/documents/foobar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foobar","foo":"baz"}'
  end

  it "should get the document edit history" # do
   #    post '/documents', {:id => 'foo', :counter => 0}
   #    put '/documents/foo', {:id => 'foo', :counter => 1}
   #    put '/documents/foo', {:id => 'foo', :counter => 2}
   # 
   #    get '/documents/foo/history'
   #    last_response.status.should == 200
   #    last_response.headers["Content-Type"].should == "application/json"
   # 
   #    (JSON last_response.body).size.should == 3
   #  end
end
