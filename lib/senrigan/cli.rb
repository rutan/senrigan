# frozen_string_literal: true

module Senrigan
  class CLI
    def initialize(argv)
      @argv = argv.clone
    end

    def run!
      clear_terminal
      show_header
      formatter = Senrigan::Formatter.new
      adapter = Senrigan::Adapter.new
      adapter.on do |entity|
        formatter.format_print(entity)
      end
      adapter.connect!
    rescue Interrupt
      exit 0
    end

    private

    def clear_terminal
      print "\e[H\e[2J"
    end

    def show_header
      STDOUT.puts "[Senrigan v.#{Senrigan::VERSION}]"
      STDOUT.puts
    end
  end
end
