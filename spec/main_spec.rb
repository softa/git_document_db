require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Main" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  before(:each) do
    FileUtils.rm_rf(Document.root_path)
  end

  it "should create a document, with all JSON objects, including nested objects" do

    data = {
      "id" => 'foo',
      "foo" => {
        "bar" => 45.99,
        "foo" => true,
        "nil" => nil,
        "array" => ["1", "2", "3"]
      },
      "bar" => {
        "foo_bar" => 'bar_foo',
        "abc" => {
          "foo" => 123,
          "bar" => 456,
          "array_of_hashes" => [{ "foo" => "bar" }, { "foo" => "foobar" }]
        }
      }
    }
    
    post '/documents', data.to_json
    last_response.should be_ok
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == data
    
  end

  it "should not create a document without attributes" do
    post '/documents'
    last_response.status.should == 400
  end

  it "should not create a document without id" do
    post '/documents', { :foo => 'bar' }.to_json
    last_response.status.should == 406
  end

  it "should create a document with attributes"  do
    data = {:id => "foo", :foo => "bar", :baz => 'content'}
    post '/documents', data.to_json
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == data.to_json
  end

  it "should delete a document" do
    post '/documents', {:id => 'foobar'}.to_json
    delete '/documents/foobar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == {:id => 'foobar'}.to_json
  end
  
  it "should receive 404 response when trying to delete a document that doesn't exists" do
    delete '/documents/non_existant_document'
    last_response.status.should == 404
    last_response.body.should == ''
  end


  it "should update a document, and create new attributes if necessary" do
    
    data = {"id" => 'foobar', "foo" => 'bar'}
    post '/documents', data.to_json
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == data

    get '/documents/foobar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == data

    data = {"foo" => 'baz', "new_attribute" => 'foo'}
    put '/documents/foobar', data.to_json
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    data = data.merge("id" => "foobar")
    JSON.parse(last_response.body).should == data
    
    get '/documents/foobar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == data
    
  end

  it "should get the document's history and access specific versions" do
    
    data = {"id" => 'foo', "counter" => 0}
    post '/documents', data.to_json
    data["counter"] = 1
    put '/documents/foo', data.to_json
    data["counter"] = 2
    put '/documents/foo', data.to_json

    get '/documents/foo/history'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    history = JSON.parse(last_response.body)
    history.size.should == 3
    
    get "/documents/foo/version/#{history[2]}"
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foo","counter":0}'
    
    get "/documents/foo/version/#{history[1]}"
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foo","counter":1}'
    
    get "/documents/foo/version/#{history[0]}"
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    last_response.body.should == '{"id":"foo","counter":2}'
    
  end
  
  it "should create a fork and return the new document" do
    
    post '/documents', {"id" => "foo", "foo" => "bar"}.to_json
    post '/documents/foo/fork/bar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == {"id" => "bar", "foo" => "bar"}
    
  end
  
  it "should merge a document and return the merged document if OK" do
    
    post '/documents', {"id" => "foo", "foo" => "bar"}.to_json
    post '/documents/foo/fork/bar'
    put '/documents/bar', {:foo => "baz"}.to_json
    
    put '/documents/foo/merge/bar'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == {"id" => "foo", "foo" => "baz"}
    
  end
  
  it "should merge a document and return 409 if there were conflicts" do
    
    post '/documents', {"id" => "foo", "foo" => "bar"}.to_json
    post '/documents/foo/fork/bar'
    put '/documents/foo', {:foo => "baz"}.to_json
    put '/documents/bar', {:foo => "zab"}.to_json
    
    put '/documents/foo/merge/bar'
    last_response.status.should == 409
    
  end
  
  it "should get a list of pending merges for a document" do

    post '/documents', {"id" => "foo", "foo" => "bar", "bar" => "foo"}.to_json
    post '/documents/foo/fork/bar'
    put '/documents/foo', {:foo => "baz"}.to_json
    put '/documents/bar', {:foo => "zab"}.to_json
    put '/documents/foo/merge/bar'
    
    get '/documents/foo/pending_merges'
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    pending = JSON.parse(last_response.body)
    pending.size.should == 1
    
    merge = pending[0]
    merge["from_id"].should == "bar"
    merge["attributes"].should == {
      "foo" => {
        "conflicts" => 1,
        "sections" => 1,
        "text" => [{
          "ours" => ['"baz"'],
          "theirs" => ['"zab"'],
        }]
      }
    }

  end
  
  it "should resolve conflicts and return the merged document if OK; if not, raise 409" do
    
    post '/documents', {"id" => "foo", "foo" => "bar", "bar" => "foo"}.to_json
    post '/documents/foo/fork/bar'
    put '/documents/foo', {:foo => "baz"}.to_json
    put '/documents/bar', {:foo => "zab"}.to_json
    put '/documents/foo/merge/bar'

    put '/documents/foo/resolve_conflicts/bar', { :bar => "foo" }.to_json
    last_response.status.should == 409

    put '/documents/foo/resolve_conflicts/bar', { :foo => "abc" }.to_json
    last_response.status.should == 200
    last_response.headers["Content-Type"].should == "application/json"
    JSON.parse(last_response.body).should == {"id" => "foo", "foo" => "abc", "bar" => "foo"}
    
  end
  
end
