require './main.rb'
require 'memcached'

use Rack::ShowExceptions

run App.new