# frozen_string_literal: true

module Senrigan
  module Entities
    class Channel < Base
      attr_accessor :name, :is_private
    end
  end
end
