# frozen_string_literal: true

module WinCred
  # Responsible for converting w_char pointer to Ruby string
  module Conversion
    class << self
      def wcsnlen(ptr, maxlen = 1024)
        (0...maxlen).find { |i| (ptr[i * 2] | ptr[i * 2 + 1]).zero? }
      end

      def pwchar_to_str(ptr)
        ptr.to_str(wcsnlen(ptr) * 2).force_encoding('utf-16le')
      end
    end
  end
end
