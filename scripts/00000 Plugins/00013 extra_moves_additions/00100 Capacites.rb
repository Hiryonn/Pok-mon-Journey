# Extra Moves Additions : effets des capacités ajoutées avec Pokéngine que PSDK n'a pas.
#
# Comment ça marche : chaque effet est une méthode de combat (battleEngineMethod) enregistrée ici. Dans Studio, ouvre la capacité
# et mets « Fonction » sur la méthode voulue. Les capacités dont l'effet existe déjà dans PSDK n'ont rien à programmer :
#   - Bolt In (Acier, hausse la Vitesse du lanceur)  -> s_self_stat    (Studio : modif. de stat Vitesse +1)
#   - Abyssal Dive (Eau, emporte la cible sous l'eau, qui ne peut pas attaquer ensuite) -> s_sky_drop (même principe que Chute Libre)
#   - Fatal Tide (vague de poison qui bloque les soins) -> s_extra_heal_block_damage
#   - Oil Fire -> s_extra_rain_boost, Beach Tide -> s_extra_sun_boost, Faceplant -> s_extra_hazard_power
# Pour ajouter une capacité : crée une classe ci-dessous, enregistre-la avec Move.register(:s_extra_xxx, Classe), puis mets
# cette fonction dans la capacité. Les erreurs d'une capacité sont attrapées pour ne jamais bloquer le combat.
module Battle
  class Move
    module ExtraMovesAdditions
      # Nombre de tours des blocages (Anti-Soin)
      HEAL_BLOCK_TURNS = 5

      module_function

      # Ajoute l'effet Anti-Soin de PSDK à un Pokémon s'il ne l'a pas déjà. Renvoie true si posé.
      def block_healing(logic, target)
        return false unless defined?(Battle::Effects::HealBlock)
        return false if target.effects.has?(:heal_block)

        target.effects.add(Battle::Effects::HealBlock.new(logic, target, HEAL_BLOCK_TURNS))
        return true
      rescue StandardError => e
        log_error('block_healing', e)
        return false
      end

      def log_error(where, error)
        text = "[ExtraMovesAdditions] #{where} : #{error.class} #{error.message}"
        Kernel.respond_to?(:log_error, true) ? Kernel.send(:log_error, text) : puts(text)
      end
    end

    # Dégâts, puis les adversaires touchés ne peuvent plus se soigner (capacités, talents, objets) pendant 5 tours.
    class ExtraHealBlockDamage < Basic
      private

      def deal_effect(user, actual_targets)
        super
        actual_targets.each do |target|
          next if target.dead?

          ExtraMovesAdditions.block_healing(@logic, target)
        end
      rescue StandardError => e
        ExtraMovesAdditions.log_error('s_extra_heal_block_damage', e)
      end
    end
    Move.register(:s_extra_heal_block_damage, ExtraHealBlockDamage)
    # Oil Fire / Beach Tide : au lieu d'être affaiblie par la météo opposée, la capacité est renforcée de 50 %.
    # PSDK applique déjà ×0,5 (Feu sous la pluie, Eau sous le soleil) : on triple la puissance dans ce cas pour obtenir ×1,5.
    class ExtraWeatherBoost < Basic
      RAIN = %i[rain hardrain].freeze
      SUN = %i[sunny hardsun].freeze

      def real_base_power(user, target)
        power = super
        weather = @logic.respond_to?(:current_weather) ? @logic.current_weather : nil
        boosting = db_symbol == :oil_fire ? RAIN : SUN
        return boosting.include?(weather) ? power * 3 : power
      rescue StandardError => e
        ExtraMovesAdditions.log_error('ExtraWeatherBoost', e)
        return super
      end
    end
    Move.register(:s_extra_rain_boost, ExtraWeatherBoost)
    Move.register(:s_extra_sun_boost, ExtraWeatherBoost)

    # Faceplant : 40 de puissance, +30 par couche de piège sur le terrain de la cible (Picots 3, Pics Toxik 2, Piège de Roc 1, Toile 1).
    class ExtraHazardPower < Basic
      def real_base_power(user, target)
        return super + 30 * hazard_layers(target)
      rescue StandardError => e
        ExtraMovesAdditions.log_error('ExtraHazardPower', e)
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
    Move.register(:s_extra_hazard_power, ExtraHazardPower)
  end
end
