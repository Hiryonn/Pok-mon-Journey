# Résumé PE : bandeau du haut
module UI
  module SummaryPE
    # Bandeau du haut + grand sprite du Pokémon (partagé par les pages)
    class Header < SpriteStack
      # Position du grand sprite selon la page (bas-centre) ; absent = caché
      FACE_POSITIONS = {0 => [72, 165]}
      # Zones cliquables du bandeau
      BUTTONS = {switch: 0..15, prev: 218..251, next: 252..285, back: 286..319}

      # @return [Hash] zones des boutons (celles de droite suivent le bord droit de l'écran)
      def self.buttons
        e = SummaryPE.extra
        return {switch: 0..15, prev: (218 + e)..(251 + e), next: (252 + e)..(285 + e), back: (286 + e)..(319 + e)}
      end
      BUTTON_Y = 4..23
      # Pokémon dont le nom contient déjà le genre
      NO_GENDER = %i[nidoranf nidoranm]

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        e = SummaryPE.extra
        header = add_sprite(0, 4, SummaryPE.file('header'))
        if SummaryPE.wide?
          header.bitmap = ::Ecran.composer(SummaryPE.file('header'), :interface, 320 + e,
                                           [[0, 0, 30, 20, 0, 0, 30, 20], [30, 0, 170 + e, 20, 30, 0, 170, 20], [200 + e, 0, 120, 20, 200, 0, 120, 20]])
        end
        # Bande noire du bas, à la place de la barre de boutons
        footer = add_sprite(0, 216, SummaryPE.file('footer'))
        footer.zoom_x = (320 + e) / 320.0
        @name = add_text(18, 6, 120, 16, '', color: WHITE)
        @shiny = add_sprite(0, 10, SummaryPE.file('shiny'))
        @marks = Array.new(2) { add_sprite(0, 9, NO_INITIAL_IMAGE, type: Sprite) }
        @status = add_sprite(0, 9, NO_INITIAL_IMAGE, type: StatusSprite)
        @gender = add_sprite(0, 10, SummaryPE.file('gender_m'))
        @level = add_text(150 + e, 6, 58, 16, '', 2, color: WHITE)
        @face = add_sprite(*FACE_POSITIONS[0], NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        @page = 0
      end

      def update_graphics
        @face.update
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        egg = pokemon.egg?
        @face.data = pokemon
        @name.text = pokemon.given_name.to_s
        x = @name.x + @name.real_width + 3
        @shiny.visible = pokemon.shiny && !egg
        @shiny.x = x
        x += 12 if @shiny.visible
        x += rank_mark(pokemon, x, egg)
        @status.data = pokemon
        @status.visible = !egg && pokemon.status.to_i != 0
        @status.x = x
        @level.text = egg ? '' : "#{SummaryPE.summary_text(29)} #{pokemon.level}"
        @gender.visible = !egg && !NO_GENDER.include?(pokemon.db_symbol) && [1, 2].include?(pokemon.gender)
        @gender.set_bitmap(SummaryPE.file(pokemon.gender == 2 ? 'gender_f' : 'gender_m'), :interface)
        @gender.x = @level.x + @level.width - @level.real_width - 9
        self.page = @page
      end

      # Marques à côté de la marque chromatique : Baron / Dominant (plugin overworld_pokemon), Obscur (plugin obscurs)
      # @return [Integer] largeur prise (0 : aucune marque)
      def rank_mark(pokemon, x, egg)
        names = []
        unless egg
          names << OverworldPokemon.battle_icon(pokemon) if defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:battle_icon)
          names << Obscurs.mark_icon(pokemon) if defined?(Obscurs) && Obscurs.respond_to?(:mark_icon)
        end
        names = names.compact
        start = x
        @marks.each_with_index do |sprite, i|
          name = names[i]
          sprite.visible = !name.nil?
          next unless name

          sprite.bitmap = RPG::Cache.interface(name)
          zoom = defined?(OverworldPokemon) ? OverworldPokemon.setting('battle_icon_zoom').to_i.clamp(10, 400) / 100.0 : 0.75
          sprite.zoom_x = sprite.zoom_y = zoom
          sprite.x = x
          x += (sprite.bitmap.width * zoom).ceil + 2
        end
        return x - start
      rescue StandardError
        @marks.each { |sprite| sprite.visible = false }
        return 0
      end

      # Place le grand sprite selon la page affichée
      # @param index [Integer]
      def page=(index)
        @page = index
        position = FACE_POSITIONS[index]
        @face.visible = position ? true : false
        @face.set_position(*position) if position
      end

      # Bouton du bandeau sous la souris
      # @param mx [Integer]
      # @param my [Integer]
      # @return [Symbol, nil] :switch, :prev, :next ou :back
      def button_at(mx, my)
        return nil unless BUTTON_Y.include?(my)

        return self.class.buttons.find { |_, range| range.include?(mx) }&.first
      end
    end
  end
end
