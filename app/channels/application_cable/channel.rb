# Base channel for WorkMori — 모든 stream은 "account:{id}" prefix
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end