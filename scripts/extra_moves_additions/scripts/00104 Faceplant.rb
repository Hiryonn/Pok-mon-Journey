# Faceplant (s_extra_faceplant) : 40 de puissance, +30 par couche de piège sur le terrain de la cible
# (Picots 3, Pics Toxik 2, Piège de Roc 1, Toile Gluante 1) : 250 au maximum.
module Battle
  class Move
    class ExtraFaceplant < Basic
      PER_LAYER = 30

      def real_base_power(user, target)
        return super + PER_LAYER * hazard_layers(target)
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Faceplant', e)
        return super
      end

      private

      def hazard_layers(target)
        effects = @logic.bank_effects[target.bank]
        total = 0
        { spikes: 3, toxic_spikes: 2 }.each do |name, max|
          effect = effects.get(name)
          total += [effect.layers, max].min if effect
        end
        %i[stealth_rock sticky_web].each { |name| total += 1 if effects.has?(name) }
        return total
      end
    end
    Move.register(:s_extra_faceplant, ExtraFaceplant)
  end
end
