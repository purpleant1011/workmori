# PublisherJob — 모든 active 채널에 콘텐츠 발행
class PublisherJob < ApplicationJob
  queue_as :default

  def perform(content_id, account_id)
    content = ContentItem.find(content_id)
    account = Account.find(account_id)
    channels = account.channel_connections.where(status: "active")
    channels.each do |ch|
      Channels::Publisher.call(channel: ch, content_item: content)
    end
  end
end