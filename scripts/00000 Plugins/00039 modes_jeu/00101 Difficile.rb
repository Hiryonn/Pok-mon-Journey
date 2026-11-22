# Modes Difficile et Extrême :
#  - plafond de niveau selon les badges : un Pokémon au plafond ne gagne plus d'expérience (affiché dans l'Étui à badges)
#  - dresseurs plus forts (niveaux en plus), style de combat « Set » forcé (pas de changement offert après un K.O.)
#  - Extrême : aucun objet du sac contre les dresseurs (et en sauvage si extreme_block_wild)
module Battle
  class Logic
    class ExpHandler
      module ModesJeuCap
        # @param enemy [PFM::PokemonBattler]
        # @return [Hash{ PFM::PokemonBattler => Integer }]
        def distribute_exp_for(enemy)
          data = super
          cap = ModesJeu.level_cap
          return data unless cap && ModesJeu.setting('cap_block_exp')

          data.each_key.to_a.each do |battler|
            if battler.level >= cap
              data.delete(battler)
            else
              data[battler] = ModesJeu.clamp_exp(battler, data[battler], cap)
            end
          end
          return data
        rescue StandardError => e
          ModesJeu.log_error("plafond : #{e.message}")
          return data
        end
      end
      prepend ModesJeuCap
    end

    class BattleInfo
      class << self
        module ModesJeuTrainers
          # Randomizer (espèces) puis niveaux en plus, sur les Pokémon du dresseur qui vient d'être ajouté
          def add_trainer(battle_info, bank, id_trainer)
            super
            return unless bank != 0

            party = battle_info.parties[bank]&.last
            ModesJeu.rework_trainer_party(party) if party
          rescue StandardError => e
            ModesJeu.log_error("dresseur : #{e.message}")
          end
        end
        prepend ModesJeuTrainers
      end
    end
  end

  class Scene
    module ModesJeuExtreme
      private

      def player_action_choice_internal(choice, forced_action = nil)
        if ModesJeu.extreme? && %i[bag item].include?(choice) &&
           (@logic.battle_info.trainer_battle? || ModesJeu.setting('extreme_block_wild'))
          display_message_and_wait(ModesJeu.text(:no_items))
          return @next_update = :player_action_choice
        end
        super
      end
    end
    prepend ModesJeuExtreme
  end
end

# Style « Set » forcé
module PFM
  class Options
    module ModesJeuSet
      def battle_style
        return :set if ModesJeu.hard?

        return super
      end
    end
    prepend ModesJeuSet
  end
end

module ModesJeu
  module_function

  # Limite l'expérience gagnée pour ne pas dépasser le plafond
  def clamp_exp(battler, exp, cap)
    list = battler.original.exp_list
    room = list[cap] - battler.exp
    return room <= 0 ? 0 : [exp, room].min
  rescue StandardError
    return exp
  end

  # @param party [Array<PFM::Pokemon>] équipe d'un dresseur (modifiée sur place)
  def rework_trainer_party(party)
    party.each_index do |i|
      pokemon = party[i]
      next if pokemon.nil? || pokemon.shadow?

      party[i] = pokemon = Randomizer.replace(pokemon, :trainers) if randomizer? && setting('randomizer_trainers')
      bonus = hard? ? setting('trainer_bonus').to_i + (extreme? ? setting('extreme_trainer_bonus').to_i : 0) : 0
      next unless bonus > 0

      level = [pokemon.level + bonus, max_level].min
      pokemon.level = level if pokemon.respond_to?(:level=)
      pokemon.hp = pokemon.max_hp
    end
  end
end

# L'Étui à badges peut afficher le plafond
if defined?(GamePlay::EtuiBadges)
  module GamePlay
    class EtuiBadges
      module ModesJeuCapLine
        def refresh
          super
          cap = ModesJeu.level_cap
          return unless cap && @mode == :tray && @total

          @total.text = "#{@total.text}   #{ModesJeu.text(:cap_line)}#{cap}"
        rescue StandardError
          nil
        end
      end
      prepend ModesJeuCapLine
    end
  end
end
