# Options en plus : Multi Exp.
# Quand l'option est activée, chaque Pokémon vivant de l'équipe qui n'a pas gagné d'expérience dans le combat en reçoit
# multi_exp_percent % (50 par défaut) de l'expérience du meilleur gagnant.
module Battle
  class Logic
    class ExpHandler
      module OptionsPlusMultiExp
        # @return [Integer] niveau maximum des Pokémon
        def max_level
          return Configs.settings.respond_to?(:max_level) ? Configs.settings.max_level : 100
        end

        # @param enemy [PFM::PokemonBattler]
        # @return [Hash{ PFM::PokemonBattler => Integer }]
        def distribute_exp_for(enemy)
          data = super
          return data unless $options.respond_to?(:pj_multi_exp) && $options.pj_multi_exp
          return data if data.empty? || !@logic.respond_to?(:trainer_battlers)

          percent = OptionsPlus.setting('multi_exp_percent').to_i
          share = (data.values.max * percent / 100.0).round
          return data if share <= 0

          @logic.trainer_battlers.each do |battler|
            next if data.key?(battler) || battler.dead? || battler.egg? || battler.level >= max_level

            data[battler] = share
          end
          return data
        rescue StandardError => e
          OptionsPlus.log_error("Multi Exp. : #{e.message}")
          return data
        end
      end
      prepend OptionsPlusMultiExp
    end
  end
end
