# frozen_string_literal: true

module Senrigan
  module Entities
    class User < Base
      attr_accessor :name, :is_bot
    end
  end
end
