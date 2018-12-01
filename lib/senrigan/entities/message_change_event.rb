# frozen_string_literal: true

module Senrigan
  module Entities
    class MessageChangeEvent < Base
      attr_accessor :ts, :edited_message, :previous_message
    end
  end
end
