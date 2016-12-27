module Redata
	class Notice
		def initialize
			Log.error! "ERROR: slack bot token missing" if !RED.slack['token'] || RED.slack['token'].empty?
			@slack = Slack::Client.new :token => RED.slack['token']
			channel_exist = false
			@slack.channels_list['channels'].each do |channel|
				channel_exist = true if channel['name'] == RED.slack['channel']
			end
			Log.error! "ERROR: slack channel #{RED.slack['channel']} not exists" unless channel_exist
		end

		def send(msg)
			@slack.chat_postMessage({
				:channel => RED.slack['channel'],
				:text => "<!here> #{msg}",
				:as_user => true
			})
		end
	end
end
