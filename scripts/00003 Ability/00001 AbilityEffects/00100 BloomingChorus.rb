module Battle
  module Effects
    class Ability
      class BloomingChorus < Ability
        def on_switch_event(handler, who, with)
          return if with != @target

          ko_count = handler.logic.retrieve_party_from_battler(@target).count { |p| p.hp <= 0 && p != @target }
          stages = [ko_count, 3].min

          if stages > 0 && handler.logic.stat_change_handler.stat_increasable?(:ats, @target)
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(
                    parse_text_with_pokemon(400003, 24, @target)
            )
            handler.logic.stat_change_handler.stat_change_with_process(:ats, stages, @target)
          end
        end
      end
      register(:blooming_chorus, BloomingChorus)
    end
  end
end
