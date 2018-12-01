# frozen_string_literal: true

require 'colorize'

module Senrigan
  class Formatter
    def initialize
    end

    def format(entity)
      case entity
      when Entities::Message
        format_message(entity)
      when Entities::MessageChangeEvent
        format_message_change_event(entity)
      else
        entity.inspect
      end
    end

    def format_print(entity)
      str = format(entity)
      STDOUT.puts str unless str.empty?
    end

    def format_message(entity)
      lines = []
      lines.push format_header(entity)
      lines.push entity.content unless entity.content.empty?
      entity.attachments.each do |attachment|
        lines.push format_attachment(attachment)
      end
      lines.push format_parent(entity.parent) if entity.parent
      lines.join("\n")
    end

    def format_message_change_event(entity)
      if entity.edited_message.content == entity.previous_message.content &&
         !entity.edited_message.attachments.empty? && entity.previous_message.attachments.empty?
        entity.edited_message.attachments.map { |a| format_attachment(a) }.join("\n")
      else
        format_message(entity.edited_message)
      end
    end

    def format_header(entity)
      [
        "@#{entity.user.name}#{entity.user.is_bot ? ' [App]' : ''}".to_s.colorize(:light_blue),
        'in',
        "#{entity.channel.is_private ? '🔒 ' : '#'}#{entity.channel.name}".colorize(:light_green),
        Time.at(entity.ts.to_i).strftime('%H:%M').colorize(:light_black)
      ].join(' ')
    end

    def format_parent(entity)
      lines = []
      lines.push [
        '>',
        "@#{entity.user.name}#{entity.user.is_bot ? ' [App]' : ''}".to_s,
        Time.at(entity.ts.to_i).strftime('%H:%M')
      ].join(' ').colorize(:light_black)
      lines.push "> #{entity.content.split(/\r?\n/).join("\n> ")}".colorize(:light_black)
      lines.join("\n")
    end

    def format_attachment(attachment)
      lines = []
      lines.push attachment.title.to_s.colorize(:green) unless attachment.title.to_s.empty?
      lines.push attachment.text.to_s.colorize(:green) unless attachment.text.to_s.empty?
      lines.push attachment.title_link.to_s.colorize(:green) unless attachment.title_link.to_s.empty?
      lines.join("\n")
    end
  end
end
