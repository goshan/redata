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

    def log(msg, log=nil)
      log_content = "```\n#{File.read(log).split("\n").map{|line| line.gsub(/\[0;\d{2};\d{2}m/, '').gsub(/\[0m/, '')}.join("\n")}\n```" if log
      @slack.chat_postMessage({
        :channel => RED.slack['channel'],
        :text => "#{msg}\n#{log_content}",
        :as_user => true
      })
    end

    def mention(user_name, msg)
      @slack.users_list['members'].each do |user|
        if user['name'] == user_name
          @slack.chat_postMessage({
            :channel => RED.slack['channel'],
            :text => "<@#{user['id']}> #{msg}",
            :as_user => true
          })
        end
      end
    end
  end
end
