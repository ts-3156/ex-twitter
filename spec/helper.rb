require 'twitter_with_auto_pagination'
require 'rspec'
require 'stringio'
require 'tempfile'
require 'timecop'
require 'webmock/rspec'

require_relative 'support/media_object_examples'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

BASE_URL = 'https://api.twitter.com'.freeze

def a_delete(path)
  a_request(:delete, BASE_URL + path)
end

def a_get(path)
  a_request(:get, BASE_URL + path)
end

def a_post(path)
  a_request(:post, BASE_URL + path)
end

def a_put(path)
  a_request(:put, BASE_URL + path)
end

def stub_delete(path)
  stub_request(:delete, BASE_URL + path)
end

def stub_get(path)
  stub_request(:get, BASE_URL + path)
end

def stub_post(path)
  stub_request(:post, BASE_URL + path)
end

def stub_put(path)
  stub_request(:put, BASE_URL + path)
end

def fixture_path
  File.expand_path('../fixtures', __FILE__)
end

def fixture(file)
  File.new(fixture_path + '/' + file)
end

def capture_warning
  begin
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    result = $stderr.string
  ensure
    $stderr = old_stderr
  end
  result
end
