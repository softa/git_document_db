require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'

set :environment, :test

require File.join(File.dirname(__FILE__), '..', 'main')
