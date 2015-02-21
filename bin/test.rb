require 'ex_twitter'
require 'pp'

config = YAML.load_file('config/twitter.yml')
client = ExTwitter.new(config)

pp client.user.attrs
