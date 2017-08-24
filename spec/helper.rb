require 'dotenv/load'
require 'twitter_with_auto_pagination'
require 'rspec'

RSpec.configure do |config|
  config.before(:suite) do
    $fetch_count = $request_count = 0

    set_trace_func proc { |event, file, line, id, binding, klass|
      if klass == TwitterWithAutoPagination::Cache && id == :fetch && event == 'call'
        $fetch_called = true
        $fetch_count += 1
      end
      if klass == Twitter::REST::Request && id == :perform && event == 'call'
        $request_called = true
        $request_count += 1
      end
    }
  end

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec::Matchers.define :fetch do
  match do |actual|
    before = $fetch_called
    actual.call
    @count = 1 if @count.nil?
    @actual_count = $fetch_count
    result = !before && $fetch_called && @actual_count == @count

    $fetch_called = false
    $fetch_count = 0

    result
  end

  chain(:once) { @count = 1 }
  chain(:twice) { @count = 2 }
  chain(:exactly) { |count| @count = count }
  chain(:times) {}

  failure_message do |actual|
    "expected to call #fetch #{@count} times but called #{@actual_count} times"
  end

  supports_block_expectations
end

RSpec::Matchers.define :request do
  match do |actual|
    before = $request_called
    actual.call
    @count = 1 if @count.nil?
    @actual_count = $request_count
    result = !before && $request_called && @actual_count == @count

    $request_called = false
    $request_count = 0

    result
  end

  chain(:once) { @count = 1 }
  chain(:twice) { @count = 2 }
  chain(:exactly) { |count| @count = count }
  chain(:times) {}

  failure_message do |actual|
    "expected to call #request #{@count} times but called #{@actual_count} times"
  end

  supports_block_expectations
end

RSpec::Matchers.define :not_fetch do
  match do |actual|
    before = $fetch_called
    actual.call
    after = $fetch_called
    $fetch_called = false
    !before && !after
  end

  failure_message { |actual| 'expected not to fetch' }
  supports_block_expectations
end

RSpec::Matchers.define :not_request do
  match do |actual|
    before = $request_called
    actual.call
    after = $request_called
    $request_called = false
    !before && !after
  end

  failure_message { |actual| 'expected not to request' }
  supports_block_expectations
end

RSpec::Matchers.define :match_twitter do |expected|
  match do |actual|
    if expected.is_a?(Array)
      if expected[0].is_a?(Integer)
        actual == expected
      else
        actual.map { |r| r[:id] } == expected.map { |r| r[:id] }
      end
    elsif expected.is_a?(Hash)
      actual[:id] == expected[:id]
    else
      actual == expected
    end
  end
end

RSpec.shared_examples 'continuous calls' do
  it 'fetches the result from a cache for the second time' do
    result1 = result2 = nil
    expect { result1 = client.send(name, *params) }.to fetch & request
    expect { result2 = client.send(name, *params) }.to fetch & not_request
    expect(result1).to match_twitter(result2)
  end
end

RSpec.shared_examples 'cache: false is specified' do
  it 'sends http requests' do
    expect { client.send(name, *params) }.to fetch & request
    expect { client.send(name, *params, cache: false) }.to not_fetch & request
  end
end

RSpec.shared_examples 'when a value is changed' do
  it 'sends http requests' do
    expect { client.send(name, *params) }.to fetch & request
    expect { client.send(name, *params2) }.to fetch & request
  end
end

RSpec.shared_examples 'when options are changed' do
  it 'sends http requests' do
    expect { client.send(name, *params) }.to fetch & request
    expect { client.send(name, *params, hello: :world) }.to fetch & request
  end
end

RSpec.shared_examples 'when a client is changed, it shares a cache' do
  it 'shares a cache' do
    expect { client.send(name, *params) }.to fetch & request
    expect { client2.send(name, *params) }.to fetch & not_request
  end
end

RSpec.shared_examples 'when a client is changed, it does not share a cache' do
  it 'does not share a cache' do
    expect { client.send(name, *params) }.to fetch & request
    expect { client2.send(name, *params) }.to fetch & request
  end
end

RSpec.shared_examples 'when one param is specified, it raises an exception' do
  it 'raises an exception' do
    expect { client.send(name, id) }.to raise_error(ArgumentError)
  end
end

RSpec.shared_examples 'when any params is not specified, it raises an exception' do
  it 'raises an exception' do
    expect { client.send(name) }.to raise_error(ArgumentError)
  end
end

RSpec.shared_examples 'when any params is not specified, it returns a same result as a result with one param' do
  it 'returns a same result as a result with one param' do
    result1 = result2 = nil
    expect { result1 = client.send(name) }.to fetch & request
    expect { result2 = client.send(name, id) }.to fetch & request
    expect(result1).to match_twitter(result2)
  end
end

RSpec.shared_examples 'when count is specified' do |count|
  it 'requests twice' do
    result1 = result2 = nil
    expect { result1 = client.send(name, *params, count: count) }.to fetch & request.twice
    expect { result2 = client.send(name, *params, count: count) }.to fetch & not_request
    expect(result1.size).to be > (count / 2)
    expect(result1).to match_twitter(result2)
  end
end
