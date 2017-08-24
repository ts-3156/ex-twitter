require 'helper'

describe TwitterWithAutoPagination::Client do
  let(:client) do
    described_class.new(
      consumer_key: ENV['CK'],
      consumer_secret: ENV['CS'],
      access_token: ENV['AT'],
      access_token_secret: ENV['ATS']
    )
  end
end
