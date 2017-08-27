require 'helper'

describe TwitterWithAutoPagination::REST::Lists do
  let(:config) do
    {
      consumer_key: ENV['CK'],
      consumer_secret: ENV['CS'],
      access_token: ENV['AT'],
      access_token_secret: ENV['ATS']
    }
  end

  let(:config2) do
    {
      consumer_key: ENV['CK2'],
      consumer_secret: ENV['CS2'],
      access_token: ENV['AT2'],
      access_token_secret: ENV['ATS2']
    }
  end

  let(:client) { TwitterWithAutoPagination::Client.new(config) }
  let(:client2) { TwitterWithAutoPagination::Client.new(config2) }

  let(:id) { 58135830 }
  let(:id2) { 22356250 }

  before do
    client.cache.clear
    $fetch_called = $request_called = false
    $fetch_count = $request_count = 0
  end

  describe '#memberships' do
  end

  describe '#list_members' do
  end
end
