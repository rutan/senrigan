# frozen_string_literal: true

module Senrigan
  module Entities
    class Message < Base
      attr_accessor :ts, :channel, :user, :content, :parent
      attr_writer :attachments

      def attachments
        @attachments ||= []
      end
    end
  end
end
