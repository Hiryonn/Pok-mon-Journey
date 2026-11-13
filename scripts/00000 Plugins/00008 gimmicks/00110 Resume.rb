# Gimmicks : résumé du Pokémon (interface_pe)
#
# Page Infos : icône du type Téra au bout de la ligne des types.
# Page Mémo : le cadre gris de gauche montre le niveau Dynamax (icône Gigamax devant les barres si le Pokémon a le facteur).
module Gimmicks
  SUMMARY_TEXTS = {
    dynamax_level: ['Niveau Dynamax', 'Dynamax Level'],
    gmax: ['Facteur Gigamax', 'Gigantamax Factor'],
    tera_type: ['Type Téra', 'Tera Type'],
    yes: %w[Oui Yes],
    no: %w[Non No]
  }.freeze

  module_function

  # @param key [Symbol]
  # @return [String]
  def summary_text(key)
    return SUMMARY_TEXTS[key][$options&.language == 'fr' ? 0 : 1]
  rescue StandardError
    return SUMMARY_TEXTS[key].first
  end
end

module UI
  module SummaryPE
    class InfoPage
      module PJGimmicksTera
        # Position de l'icône du type Téra (bout de la ligne des types)
        TERA_ICON_X = 291
        TERA_ICON_Y = 67

        def visible=(value)
          super
          @pj_tera_icon.visible = false if @pj_tera_icon && value && !pj_show_tera?
        end

        private

        def create_values
          super
          @pj_tera_icon = add_sprite(TERA_ICON_X, TERA_ICON_Y, Gimmicks.file('tera_types'))
          @pj_tera_icon.src_rect.set(0, 0, 16, 16)
          @pj_tera_icon.visible = false
        end

        def refresh(pokemon)
          super
          return unless @pj_tera_icon

          @pj_tera_icon.visible = pj_show_tera?
          @pj_tera_icon.src_rect.set(0, Gimmicks.tera_row(pokemon.pj_tera_type) * 16, 16, 16) if @pj_tera_icon.visible
        rescue StandardError => e
          log_error("Gimmicks : résumé, type Téra (#{e.message})") if respond_to?(:log_error, true)
          @pj_tera_icon.visible = false
        end

        # @return [Boolean]
        def pj_show_tera?
          return @data && !@data.egg? && Gimmicks.enabled?(:tera) && @data.respond_to?(:pj_tera_type) ? true : false
        end
      end
      prepend PJGimmicksTera
    end

    class MemoPage
      module PJGimmicksMemo
        # Cadre gris de la page Mémo (x, largeur, haut)
        BOX_X = 4
        BOX_W = 110
        BOX_Y = 49
        # Barres du niveau Dynamax (10 barres de 6 pixels)
        BAR_W = 6

        def initialize(viewport)
          super
          pj_create_gimmick_box
        end

        def data=(pokemon)
          super
          pj_refresh_gimmick_box(pokemon)
        end

        def visible=(value)
          super
          pj_refresh_gimmick_box(@data) if value && @pj_box
        end

        private

        def pj_create_gimmick_box
          x = BOX_X
          w = BOX_W
          @pj_box = {}
          @pj_box[:dmax_title] = add_text(x, BOX_Y + 6, w, 16, Gimmicks.summary_text(:dynamax_level), 1, color: DARK)
          @pj_box[:gmax_icon] = add_sprite(x + 4, BOX_Y + 24, Gimmicks.file('icon_gmax'))
          @pj_box[:dmax_empty] = add_sprite(x + (w - 60) / 2, BOX_Y + 25, Gimmicks.file('dynamax_levels_empty'))
          @pj_box[:dmax_bars] = add_sprite(x + (w - 60) / 2, BOX_Y + 25, Gimmicks.file('dynamax_levels'))
          @pj_box[:dmax_value] = add_text(x, BOX_Y + 36, w, 16, '', 1, color: DARK)
          @pj_box.each_value { |sprite| sprite.visible = false }
        rescue StandardError => e
          log_error("Gimmicks : résumé, page Mémo (#{e.message})") if respond_to?(:log_error, true)
          @pj_box = nil
        end

        # @param pokemon [PFM::Pokemon, nil]
        def pj_refresh_gimmick_box(pokemon)
          return unless @pj_box

          @pj_box.each_value { |sprite| sprite.visible = false }
          return unless pokemon && !pokemon.egg? && visible

          if Gimmicks.enabled?(:dynamax) && pokemon.respond_to?(:pj_dynamax_level)
            level = pokemon.pj_dynamax_level.to_i.clamp(0, 10)
            %i[dmax_title dmax_empty dmax_bars dmax_value].each { |key| @pj_box[key].visible = true }
            bars = @pj_box[:dmax_bars]
            bars.src_rect.set(0, 0, level * BAR_W, bars.bitmap.height)
            bars.visible = level > 0
            @pj_box[:dmax_value].text = "#{level} / 10"
            # icône Gigamax devant les barres si le Pokémon a le facteur Gigamax
            @pj_box[:gmax_icon].visible = pokemon.pj_gmax_factor ? true : false
          end
        rescue StandardError => e
          log_error("Gimmicks : résumé, page Mémo (#{e.message})") if respond_to?(:log_error, true)
        end
      end
      prepend PJGimmicksMemo
    end
  end
end
