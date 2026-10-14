module Battle
    class Move
        class PlagueRun < Move
            private

            def effect_working?(user, actual_targets)
                if logic.field_terrain_effect.none? == false
                    return true
                end
                n = 1
                scene.logic.each_effects(user).each do |e|
                  n *= e.effect_chance_modifier(self)
                end
                return bchance?((effect_chance * n) / 100.0) && super
            end

                


            def deal_effect(user, actual_targets)
                if logic.field_terrain_effect.none? == false
                    logic.fterrain_change_handler.fterrain_change_with_process(:none)
                end
            end

            
        end
        Move.register(:s_plague_run, PlagueRun)
        public
    end
end
