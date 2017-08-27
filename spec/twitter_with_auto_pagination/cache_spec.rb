require 'helper'

describe TwitterWithAutoPagination::Cache do
  let(:cache) { TwitterWithAutoPagination::Cache.new }

  # describe '#fetch' do
  #
  #   before do
  #     cache.client.clear
  #   end
  #
  #   context 'with a stored value' do
  #     before do
  #       cache.client.write('key', 1)
  #       allow(cache).to receive(:normalize_key).and_return('key')
  #     end
  #     it 'calls a block' do
  #       expect { |b| cache.fetch('anything', 'user', &b)}.to yield_control
  #     end
  #   end
  #
  #   context 'without any value' do
  #     before do
  #       allow(cache).to receive(:normalize_key).and_return('key')
  #     end
  #     it 'does not call a block' do
  #       expect { |b| cache.fetch('anything', 'user', &b)}.to_not yield_control
  #     end
  #   end
  # end

  describe '#normalize_key' do
    it 'returns a key' do
      expect(cache.send(:normalize_key, :search, 'a')).to match(/\Asearch:query:a/)
      expect(cache.send(:normalize_key, :friendship?, %w(a b))).to match(/\Afriendship\?:from:a:to:b/)
      expect(cache.send(:normalize_key, :anything, 1)).to match(/\Aanything:id:/)
      expect(cache.send(:normalize_key, :anything, 'a')).to match(/\Aanything:screen_name:a:options:empty\z/)
      expect(cache.send(:normalize_key, :anything, 'a', {count: 10})).to match(/\Aanything:screen_name:a:options:count:10\z/)
      expect {cache.send(:normalize_key, :anything, nil)}.to raise_error(RuntimeError)
    end

  end

  describe '#user_identifier' do
    it 'returns a serialized string' do
      expect(cache.send(:user_identifier, 1)).to eq('id:1')
      expect(cache.send(:user_identifier, 'abc')).to eq('screen_name:abc')
      expect(cache.send(:user_identifier, [1, 2])).to match(/\Aids:2-\w+\z/)
      expect(cache.send(:user_identifier, %w(abc cde fgh))).to match(/\Ascreen_names:3-\w+\z/)
      expect { cache.send(:user_identifier, nil) }.to raise_error(RuntimeError)
    end
  end

  describe '#options_identifier' do
    it 'returns serialized string' do
      expect(cache.send(:options_identifier, a: 1, b: 2)).to match(/\Aoptions:a:1,b:2\z/)
    end

    context 'empty options' do
      it 'returns serialized string ends with "empty"' do
        expect(cache.send(:options_identifier, {})).to eq("options:empty")
      end
    end
  end

  describe '#hexdigest' do
    it 'returns hexdigest' do
      expect(cache.send(:hexdigest, 'hello')).to eq(Digest::MD5.hexdigest('hello'))
    end
  end
end
