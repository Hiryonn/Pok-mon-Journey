module UI
  module Options
    class RandomizerButton < Button
      # Retreive the option value text
      # @return [String]
      def value_text
        return format(@option.values_text, @value == -1 ? ext_text(700, 2) : @value) if @option.type == :slider

        @option.values_text[value_index]
      end
    end
  end
end
