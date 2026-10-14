module Battle
    class Move
        class DogFight < BasicWithSuccessfulEffect
            def damages(user, target)
                hp_dealt = super
                if target.type_flying?
                    hp_dealt *= 2
                elsif target.has_ability?(:levitate)
                    hp_dealt *= 2
                elsif target.effects.has? { |effect| %i[magnet_rise telekinesis].include?(effect.name) }
                    hp_dealt *=2
                else
                    nil
                end
                return hp_dealt
            end
        end
        Move.register(:s_dog_fight , DogFight)
        
    end
end