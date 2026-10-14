module Battle
  module Effects
    class Ability
      class RadiantEdge < Ability
        SLICING_MOVES = %i[
          air_cutter
          cut
          leaf_blade
          night_slash
          psycho_cut
          razor_leaf
          sacred_sword
          slash
          solar_blade
          x_scissor
          bitter_blade
          ceaseless_edge
          kowtow_cleave
          population_bomb
          gleaming_cleave
          mana_blade
          subzero_slash
          clever_cleave
          hydro_slice
        ]

        def on_post_damage(handler, hp, target, launcher, skill)
          return unless launcher == @target
          return unless skill && SLICING_MOVES.include?(skill.db_symbol)
          return if target.dead?

          handler.scene.visual.show_ability(@target)
          handler.logic.stat_change_handler.stat_change_with_process(:dfe, -1, target)
        end
      end

      register(:radiant_edge, RadiantEdge)
    end
  end
end
