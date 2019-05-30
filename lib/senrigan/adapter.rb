# frozen_string_literal: true

require 'ostruct'
require 'cgi'
require 'gemoji'
require 'slack-ruby-client'

module Senrigan
  class Adapter
    def initialize(options = {})
      @options = options
      setup_slack
      @client = ::Slack::Web::Client.new
      @handlers = []
      @message_list = []
    end

    def on(&block)
      @handlers.push(block)
    end

    def connect!
      loop do
        regenerate_cache
        @rtm = nil
        begin
          @rtm = ::Slack::RealTime::Client.new
          @rtm.on(:message, &method(:on_message))
          @rtm.start!
        rescue StandardError => e
          STDOUT.puts e.inspect if ENV['DEBUG'].to_i != 0
        end
        sleep 5
      end
    end

    private

    def setup_slack
      ::Slack.configure do |config|
        config.token = access_token
      end
    end

    def access_token
      return ENV['SLACK_TOKEN'] if ENV['SLACK_TOKEN']

      raise 'please set `ENV["SLACK_TOKEN"]` !'
    end

    def regenerate_cache
      @channel_caches = (
          @client.channels_list['channels'] +
          @client.groups_list['groups']
        ).map { |c| [c['id'], c] }.to_h
      @user_caches = @client.users_list['members'].map { |u| [u['id'], u] }.to_h
    end

    def fetch_user(user_id)
      @user_caches[user_id] ||= begin
        resp = @client.users_info(
          user: user_id
        )
        resp['channel'] || OpenStruct.new
      end
    end

    def fetch_channel(channel_id)
      @channel_caches[channel_id] ||= begin
        data =
          case channel_id.first
          when 'C'
            resp = @client.conversations_info(
              channel: channel_id
            )
            resp['channel']
          when 'G'
            resp = @client.groups_info(
              channel: channel_id
            )
            resp['group']
          else
            OpenStruct.new(name: channel_id, is_private: true)
          end
        data || OpenStruct.new(name: channel_id, is_private: false)
      end
    end

    def on_message(msg)
      entity =
        case
        when msg.subtype == 'message_changed'
          create_message_change_event_entity(msg)
        when msg.subtype.nil?, msg.subtype == 'bot_message'
          create_message_entity(msg)
        end
      return unless entity

      @message_list.push(entity)

      @handlers.each do |handler|
        handler.call(entity)
      end
    end

    def create_message_entity(msg)
      Entities::Message.new(
        ts: msg.ts,
        channel: pick_channel_from_message(msg),
        user: pick_user_from_message(msg),
        content: format_text(msg.text),
        attachments: create_attachment_entities(msg.attachments),
        parent: msg.thread_ts ? @message_list.find { |m| m.ts == msg.thread_ts } : nil
      )
    end

    def create_message_change_event_entity(msg)
      channel = pick_channel_from_message(msg)
      user = pick_user_from_message(msg)
      parent = msg.message.thread_ts ? @message_list.find { |m| m.ts == msg.message.thread_ts } : nil
      Entities::MessageChangeEvent.new(
        ts: msg.ts,
        edited_message: Entities::Message.new(
          ts: msg.message.ts,
          channel: channel,
          user: user,
          content: format_text(msg.message.text),
          attachments: create_attachment_entities(msg.message.attachments),
          parent: parent
        ),
        previous_message: Entities::Message.new(
          ts: msg.previous_message.ts,
          channel: channel,
          user: user,
          content: format_text(msg.previous_message.text),
          attachments: create_attachment_entities(msg.previous_message.attachments),
          parent: parent
        )
      )
    end

    def create_attachment_entities(attachments)
      return [] unless attachments

      attachments.map do |attachment|
        Entities::Attachment.new(
          title: format_text(attachment.title),
          text: format_text(attachment.text),
          title_link: attachment.title_link
        )
      end
    end

    def pick_channel_from_message(msg)
      case
      when msg.channel
        channel = fetch_channel(msg.channel)
        Entities::Channel.new(
          name: channel&.name || msg.channel,
          is_private: channel ? (channel.is_private || channel.is_group || channel.is_mpim) : false
        )
      end
    end

    def pick_user_from_message(msg)
      case
      when msg.username
        Entities::User.new(
          name: msg.username,
          is_bot: true
        )
      when msg.user, msg.message&.user
        user = fetch_user(msg.user || msg.message.user)
        name = [user&.profile&.display_name, user&.name, msg.user].find { |n| !n.nil? && !n.empty? }
        Entities::User.new(
          name: name.to_s,
          is_bot: user&.is_bot
        )
      else
        Entities::User.new(name: '', is_bot: true)
      end
    end

    def format_text(src_text)
      text = src_text.to_s.dup
      text.gsub!(/\\b/, '')
      text.gsub!(/\<\@(U[^>\|]+)\>/) do
        "@#{fetch_user(Regexp.last_match(1)).name}"
      end
      text.gsub!(/\<\@(U[^\|]+)\|([^>]+)\>/) do
        "@#{fetch_user(Regexp.last_match(1)).name}"
      end
      text.gsub!(/\<\#(C[^>\|]+)\>/) do
        "##{fetch_channel(Regexp.last_match(1)).name}"
      end
      text.gsub!(/\<\#(C[^\|]+)\|([^>]+)\>/) do
        "##{fetch_channel(Regexp.last_match(1)).name}"
      end
      text.gsub!(/<[^\|>]+\|([^>]+)>/, '\1')
      text.gsub!(/<|>/, '')
      text.gsub!(/:([^\:]+):/) do
        emoji = Emoji.find_by_alias(Regexp.last_match(1))
        emoji ? "#{emoji.raw} " : ":#{Regexp.last_match(1)}:"
      end
      text.gsub!(/\!(here|channel|group)/, '@\1')
      CGI.unescapeHTML(text)
    end
  end
end
