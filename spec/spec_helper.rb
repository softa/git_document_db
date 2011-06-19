require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
require File.join(File.dirname(__FILE__), '..', 'main')

set :environment, :test
