# Interface Horizon : touches (GamePlay::KeyBinding), en pleine largeur
#
# - bandeau du Pokédex Horizon en haut (la plaque « TOUCHES » reste intacte, les côtés couvrent toute la largeur)
# - tableau bleu acier du sac Horizon (lignes à filets, curseur clair) : touche PSDK, description, association
#   (clavier x4 + manette) ; la ligne choisie est en texte sombre sur le curseur
# - le fonctionnement (choix de la touche, enregistrement, manette) reste celui de PSDK
# Pour revenir au tableau de PSDK : passer ENABLED à false.
module UI
  module KeyBindingHorizon
    # Active ou non le nouveau tableau des touches
    ENABLED = true
    # Haut du tableau (sous le bandeau de 28 px)
    PANEL_Y = 32
    # Hauteur d'une ligne
    ROW_HEIGHT = 16
    # Largeur des 5 boutons (4 touches + manette)
    BUTTONS_WIDTH = 80
    # Titre du bandeau (français, anglais)
    TITLE = %w[TOUCHES KEYS].freeze
    WHITE = 9
    DARK = 0
  end

  # Tableau des touches (même interface que UI::KeyBindingViewer)
  class KeyBindingHorizonViewer < KeyBindingViewer
    # @param viewport [Viewport]
    def initialize(viewport)
      SpriteStack.instance_method(:initialize).bind_call(self, viewport, 0, 0)
      create_sprites
      @counter = 0
      self.main_index = 0
      self.key_index = -1
      self.blinking = false
    end

    # @param value [Integer]
    def main_index=(value)
      value = KEYS.size - 1 if value < 0
      value = 0 if value >= KEYS.size
      @main_index = value
      y = row_y(value)
      @sub_selector.y = y + 1
      @cursor.set_position(@panel_x - 2, y - 4)
      refresh_colors
    end

    # @param value [Integer]
    def key_index=(value)
      value = -1 if value < 0
      @key_index = value
      if value == -1
        @sub_selector.visible = false
      else
        @sub_selector.visible = true
        @sub_selector.x = @buttons_x + 16 * value + 1
      end
    end

    private

    # @param index [Integer] ligne de touche (0 = A) ; la ligne -1 est celle des titres de colonnes
    # @return [Integer]
    def row_y(index)
      return KeyBindingHorizon::PANEL_Y + 4 + (index + 1) * KeyBindingHorizon::ROW_HEIGHT
    end

    def create_sprites
      bag = UI::BagHorizon
      @panel_x = bag.gauche + 8
      panel_width = bag.largeur - 16
      @buttons_x = @panel_x + panel_width - 8 - KeyBindingHorizon::BUTTONS_WIDTH
      @panel = bag::Wide.new(@viewport, 'list', panel_width, 8, 8)
      @panel.set_position(@panel_x, KeyBindingHorizon::PANEL_Y)
      @panel.z = 5
      @cursor = bag::Wide.new(@viewport, 'cursor', panel_width + 4, 8, 8)
      @cursor.z = 6
      @sub_selector = push(@buttons_x + 1, 0, 'key_binding/selecteur_red').set_z(9)
      @row_texts = []
      create_top_line
      create_keys
    end

    def create_top_line
      first_x = @panel_x + 8
      second_x = @panel_x + 80
      y = row_y(-1)
      [[first_x, 0], [second_x, 1], [@buttons_x, 2]].each do |x, id|
        text = add_text(x, y, 100, 16, ext_text(8998, id), color: KeyBindingHorizon::WHITE)
        text.z = 7
      end
    end

    def create_key(index, name, psdk_text_id, descr_text_id)
      y = row_y(index)
      first = add_text(@panel_x + 8, y, 70, 16, ext_text(8998, psdk_text_id), color: KeyBindingHorizon::WHITE)
      second = add_text(@panel_x + 80, y, @buttons_x - @panel_x - 84, 16, ext_text(8998, descr_text_id), color: KeyBindingHorizon::WHITE)
      [first, second].each { |text| text.z = 7 }
      @row_texts << [first, second]
      4.times do |i|
        @buttons << push(@buttons_x + i * 16, y, nil, name, i, type: KeyBinding).set_z(8)
      end
      @buttons << push(@buttons_x + 64, y, nil, name, type: JKeyBinding).set_z(8)
    end

    # Texte sombre sur la ligne choisie, blanc sur les autres
    def refresh_colors
      @row_texts.each_with_index do |texts, index|
        color = index == @main_index ? KeyBindingHorizon::DARK : KeyBindingHorizon::WHITE
        texts.each { |text| text.load_color(color) }
      end
    end
  end
end

module GamePlay
  class KeyBinding
    # Habillage Horizon de la scène des touches
    module HorizonStyle
      private

      # Bandeau du Pokédex Horizon avec le titre dans la plaque
      def create_overlay
        return super unless UI::KeyBindingHorizon::ENABLED && defined?(UI::BagHorizon)

        @overlay = Sprite.new(@viewport).set_bitmap('horizon/header', :interface)
        @overlay.z = 6
        if defined?(::Ecran) && ::Ecran.cadre?(@viewport)
          extras = ::Ecran.elargir_plaque(@overlay, 80, 240)
          extras.each { |sprite| sprite.z = 6 }
          add_disposable(*extras)
        end
        add_horizon_title
      end

      def add_horizon_title
        text = UI::KeyBindingHorizon::TITLE[$options&.language.to_s == 'fr' ? 0 : 1]
        skin = UI::HorizonSkin
        @horizon_title = Text.new(0, @viewport, skin::TITLE_X, skin::TITLE_Y - Text::Util::FOY, skin::TITLE_W, 16, text, 1, Text::Util::DEFAULT_OUTLINE_SIZE, 9)
        @horizon_title.draw_shadow = false
        @horizon_title.z = skin::TITLE_Z
      end

      def create_ui
        return super unless UI::KeyBindingHorizon::ENABLED && defined?(UI::BagHorizon)

        @ui = UI::KeyBindingHorizonViewer.new(@viewport)
      end
    end
    prepend HorizonStyle
  end
end
