# Pokémon Obscurs : résumé (jauge cœur à la place de l'expérience, nature cachée)
module Obscurs
  module_function

  def gauge_text(pokemon)
    return t('Prêt à être purifié !', 'Ready to purify!') if pokemon.purifiable?

    return t("#{pokemon.heart_stage} / 5 barres", "#{pokemon.heart_stage} / 5 bars")
  end
end

if defined?(UI::SummaryPE::InfoPage)
  module UI
    module SummaryPE
      class InfoPage
        module ObscursGauge
          def visible=(value)
            super
            shadow = @data.respond_to?(:shadow?) && @data.shadow?
            @pj_heart.visible = false if @pj_heart && value && !shadow
            @exp_fill.visible = false if value && shadow
          end

          private

          def refresh(pokemon)
            super
            @pj_heart ||= add_sprite(180, 189, Obscurs.file('jauge_resume'))
            shadow = pokemon.respond_to?(:shadow?) && pokemon.shadow?
            @pj_heart.visible = shadow
            @exp_fill.visible = !shadow && !pokemon.egg?
            return restore_exp_labels unless shadow

            @exp_label.text = Obscurs.t('Jauge cœur', 'Heart Gauge')
            @exp.text = Obscurs.gauge_text(pokemon)
            @next_label.text = Obscurs.t('Expérience gardée', 'Stored Exp.')
            @next.text = pokemon.shadow_exp.to_s
            @pj_heart.src_rect.set(0, 0, (EXP_WIDTH * pokemon.heart_gauge.to_f / pokemon.max_heart_gauge).ceil.clamp(0, EXP_WIDTH), 4)
          end

          def restore_exp_labels
            @exp_label.text = SummaryPE.summary_text(10)
            @next_label.text = SummaryPE.summary_text(12)
          end
        end
        prepend ObscursGauge
      end

      class StatsPage
        module ObscursNature
          private

          # Nature cachée : pas de couleur sur les stats
          def refresh_nature(pokemon)
            return super unless pokemon.respond_to?(:shadow?) && pokemon.shadow?

            0.upto(5) do |i|
              @values[i].load_color(WHITE)
              @signs[i].text = ''
            end
          end
        end
        prepend ObscursNature
      end
    end
  end
end
