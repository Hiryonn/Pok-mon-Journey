# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00100_NewBalls.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module Battle
  class Logic
    class CatchHandler < ChangeHandlerBase
      BALL_TYPE_BONUS = { storm_ball: { types: [:type_electric?, :type_flying?], bonus: 3.5, malus_types: { types: [:type_ground?], malus: 1.5 } }, garden_ball: { types: [:type_grass?, :type_fairy?], bonus: 3.5 }, magma_ball: { types: [:type_fire?, :type_rock?], bonus: 3.5, malus_types: { types: [:type_water?], malus: 1.5 } }, mystic_ball: { types: [:type_psychic?, :type_ghost?], bonus: 3.5 }, evil_ball: { types: [:type_poison?, :type_dark?], bonus: 3.5 }, smash_ball: { types: [:type_normal?, :type_fighting?], bonus: 3.5 }, terra_ball: { types: [:type_ground?, :type_steel?], bonus: 3.5 }, wyrm_ball: { types: [:type_ice?, :type_dragon?], bonus: 3.5, malus_types: { types: [:type_fairy?], malus: 1.5 } } }

      BALL_TYPE_BONUS.each do |ball, data|
        add_ball_rate_calculation(ball) do |target, _pkm_ally|
          bonus_applied = data[:types].any? { |type| target.send(type) } ? data[:bonus] : 1
          malus_applied = data.dig(:malus_types, :types)&.any? { |type| target.send(type) } ? data.dig(:malus_types, :malus) : 1
          final_bonus = bonus_applied / malus_applied
          next target.rareness * final_bonus
        end
      end
    end
  end
end
