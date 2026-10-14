module Battle
    class Move
      def calc_type_n_multiplier(target, type_to_check, types)
        target_type = target.send(type_to_check)
        result = types.inject(1) { |product, type| product * calc_single_type_multiplier(target, target_type, type) }
        if @effectiveness >= 0
          @effectiveness *= result
          @effectiveness = 1 if target.effects.has?(:hunker) && @effectiveness >= 1
          log_data("multiplier of #{type_to_check} (#{data_type(target_type).name}) = #{result} => new_eff = #{@effectiveness}")
        end
        
        return result
      end
    end
end