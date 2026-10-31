# Résumé PE : bandeau du haut
module UI
  module SummaryPE
    # Bandeau du haut + grand sprite du Pokémon (partagé par les pages)
    class Header < SpriteStack
      # Position du grand sprite selon la page (bas-centre) ; absent = caché
      FACE_POSITIONS = {0 => [72, 165]}
      # Zones cliquables du bandeau
      BUTTONS = {switch: 0..15, prev: 218..251, next: 252..285, back: 286..319}
      BUTTON_Y = 4..23
      # Pokémon dont le nom contient déjà le genre
      NO_GENDER = %i[nidoranf nidoranm]

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 4, SummaryPE.file('header'))
        # Bande noire du bas, à la place de la barre de boutons
        add_sprite(0, 216, SummaryPE.file('footer'))
        @name = add_text(18, 6, 120, 16, '', color: WHITE)
        @shiny = add_sprite(0, 10, SummaryPE.file('shiny'))
        @status = add_sprite(0, 9, NO_INITIAL_IMAGE, type: StatusSprite)
        @gender = add_sprite(0, 10, SummaryPE.file('gender_m'))
        @level = add_text(150, 6, 58, 16, '', 2, color: WHITE)
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
        @status.data = pokemon
        @status.visible = !egg && pokemon.status.to_i != 0
        @status.x = x
        @level.text = egg ? '' : "#{SummaryPE.summary_text(29)} #{pokemon.level}"
        @gender.visible = !egg && !NO_GENDER.include?(pokemon.db_symbol) && [1, 2].include?(pokemon.gender)
        @gender.set_bitmap(SummaryPE.file(pokemon.gender == 2 ? 'gender_f' : 'gender_m'), :interface)
        @gender.x = @level.x + @level.width - @level.real_width - 9
        self.page = @page
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

        return BUTTONS.find { |_, range| range.include?(mx) }&.first
      end
    end
  end
end
