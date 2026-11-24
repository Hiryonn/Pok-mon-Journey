# Pokémon Obscurs : marque (graphics/interface/rang_obscur.png, 16 px ; rang_purifie.png une fois purifié) à côté de la barre de vie en combat
# et dans le résumé (page de l'interface Horizon : 004 Bandeau.rb). Réglages : mark, mark_icon, purified_mark_icon, mark_zoom, mark_x, mark_y.
module Obscurs
  module_function

  # @param pokemon [PFM::Pokemon, nil]
  # @return [String, nil] image (graphics/interface) de la marque d'un Pokémon Obscur ou purifié
  def mark_icon(pokemon)
    return nil unless setting('mark') && pokemon.respond_to?(:shadow?)

    key = pokemon.shadow? ? 'mark_icon' : (pokemon.respond_to?(:purified?) && pokemon.purified? ? 'purified_mark_icon' : nil)
    return nil unless key

    name = setting(key).to_s
    return name.empty? ? nil : name
  rescue StandardError
    return nil
  end

  # @return [Float] taille de la marque (1.0 : 16 px)
  def mark_zoom
    return setting('mark_zoom').to_i.clamp(10, 400) / 100.0
  end
end

module BattleUI
  class InfoBar
    # Marque Obscure
    class ShadowMark < Sprite
      # @param pokemon [PFM::Pokemon, nil]
      def data=(pokemon)
        name = Obscurs.mark_icon(pokemon)
        self.visible = !name.nil?
        return unless name

        self.bitmap = RPG::Cache.interface(name)
        self.zoom_x = self.zoom_y = Obscurs.mark_zoom
      rescue StandardError
        self.visible = false
      end
    end

    module ObscursMark
      def data=(pokemon)
        super
        return unless Obscurs.setting('mark')

        unless @pj_shadow_marks
          ax, ay = pj_shadow_anchor
          dx = Obscurs.setting('mark_x').to_i
          dy = Obscurs.setting('mark_y').to_i
          shift = (16 * Obscurs.mark_zoom).ceil + 2
          # deux places : la première, ou après la marque Baron / Dominant s'il y en a une
          @pj_shadow_marks = [add_sprite(ax + dx, ay + dy, nil, type: ShadowMark), add_sprite(ax + dx + shift, ay + dy, nil, type: ShadowMark)]
        end
        ranked = defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:battle_icon) && OverworldPokemon.battle_icon(pokemon)
        @pj_shadow_marks[0].data = ranked ? nil : pokemon
        @pj_shadow_marks[1].data = ranked ? pokemon : nil
      rescue StandardError => e
        Kernel.send(:log_error, "Obscurs : marque de combat (#{e.message})") if Kernel.respond_to?(:log_error, true) && !@pj_mark_failed
        @pj_mark_failed = true
      end
    end
    prepend ObscursMark

    private

    # Position de la marque (par rapport à la boîte) : à droite de la barre de vie, sinon à côté de la marque chromatique
    # @return [Array(Integer, Integer)]
    def pj_shadow_anchor
      bar = instance_variable_get(:@hp_bar)
      if bar.respond_to?(:x) && bar.respond_to?(:y)
        width = bar.respond_to?(:bar_width) ? bar.bar_width : (bar.respond_to?(:width) ? bar.width : 0)
        return [bar.x - x + width.to_i, bar.y - y - 6]
      end
      star = instance_variable_get(:@star)
      return [star.x - x + 8, star.y - y] if star.respond_to?(:x) && star.respond_to?(:y)

      return [0, 0]
    rescue StandardError
      return [0, 0]
    end
  end
end
