# frozen_string_literal: true

module Senrigan
  module Entities
    class Base
      def initialize(attributes = {})
        attributes.each do |k, v|
          public_send("#{k}=", v)
        end
      end
    end
  end
end
