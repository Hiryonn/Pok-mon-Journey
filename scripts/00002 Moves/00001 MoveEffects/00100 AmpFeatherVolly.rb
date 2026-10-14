module Battle
  class Move
      class AmpFeatherVolley < Basic

        def damages(user, target)
          hp_dealt = super
          hp_dealt = hp_dealt * 4 if target.type_grass? 
          @effectiveness = @effectiveness * 4 if  target.type_grass?
          hp_dealt = hp_dealt * 2 if target.type_fighting? || target.type_bug? || target.type_dragon?
          @effectiveness = @effectiveness * 2 if  target.type_fighting? || target.type_bug? || target.type_dragon?
          hp_dealt = hp_dealt * 0.5 if target.type_steel?
          @effectiveness = @effectiveness * 0.5 if target.type_steel?
          return hp_dealt
        end
      end
      Move.register(:s_amp_feather_volley, AmpFeatherVolley)
  end
end

