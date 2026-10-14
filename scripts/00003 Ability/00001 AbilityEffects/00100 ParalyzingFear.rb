module Battle
  module Effects
    class Ability
      class ParalyzingFear < Ability
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?

          foes =  logic.foes_of(@target).select(&:alive?) 
          paralysed = []
          foes.each do |foe|
              if states.include?(Configs.states.symbol(foe.status))
                  paralysed.push(foe)
              end
          end
          return unless paralysed.any?
          scene.visual.show_ability(@target) if paralysed.any?
          paralysed.each do |paralyzed_ally|
            logic.damage_handler.damage_change(paralyzed_ally.max_hp / 8, paralyzed_ally)
          end
        end
        def states
            return %i[paralysis]
        end
      end
      register(:paralyzing_fear, ParalyzingFear)
    end
  end
end
