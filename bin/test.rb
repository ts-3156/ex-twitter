require 'ex_twitter'

config = YAML.load_file('config/twitter.yml')
client = ExTwitter.new(config)

puts client.user.attrs.inspect
