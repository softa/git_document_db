require File.dirname(__FILE__) + '/spec_helper'

describe "Main" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  it "should create a document" do
    post '/documents', {:id => 'foobar'}
    last_response.should be_ok
    # TODO validate last_response.body
  end
end
