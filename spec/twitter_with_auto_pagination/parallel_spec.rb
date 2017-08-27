require 'helper'

describe TwitterWithAutoPagination::Parallel do
  let(:client) do
    TwitterWithAutoPagination::Client.new(
      consumer_key: ENV['CK'],
      consumer_secret: ENV['CS'],
      access_token: ENV['AT'],
      access_token_secret: ENV['ATS']
    )
  end

  let(:id) { 58135830 }

  describe '#parallel' do
    it 'calls #users' do
      expect(client).to receive(:users).with([id], any_args)
      client.parallel do |batch|
        batch.users([id])
      end
    end
  end
end
