# Styles de combat : interface (onglet ACTION, cadre des effets, capacités maîtrisées, titre animé, résumé)
module StylesPLA
  # Titre animé quand un Pokémon prend un style : l'écran s'assombrit, le bandeau et « STRONG STYLE » / « AGILE
  # STYLE » glissent jusqu'au centre, puis disparaissent (son : audio/se/pla_style)
  class Banner
    Z = 20_000
    BAND_Y = 76

    # @param scene [Battle::Scene]
    # @param kind [Symbol]
    def initialize(scene, kind)
      @scene = scene
      @visual = scene.visual
      @kind = kind
      @sprites = []
    end

    def play
      return unless RPG::Cache.interface_exist?(StylesPLA.file("title_#{@kind}"))

      @visual.wait_for_animation
      @viewport = Ecran.viewport(Z)
      create_sprites
      Audio.se_play('audio/se/pla_style') rescue nil
      frames(10) do |rate|
        @dark.opacity = (110 * rate).to_i
        @band.opacity = (255 * rate).to_i
        @band.x = (-120 * (1 - ease(rate))).round
        @title.x = (320 * (1 - ease(rate))).round
        @title.opacity = (255 * rate).to_i
      end
      frames(48) { |rate| @title.y = BAND_Y + (Math.sin(rate * Math::PI * 2) * 1.5).round }
      frames(10) do |rate|
        @dark.opacity = (110 * (1 - rate)).to_i
        @band.opacity = @title.opacity = (255 * (1 - rate)).to_i
        @title.x = (-60 * rate).round
      end
    rescue StandardError => e
      log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
    ensure
      dispose
    end

    private

    def create_sprites
      @dark = plain(Color.new(0, 0, 0), 0)
      @band = sprite("fade_#{@kind}", 0, BAND_Y, 1)
      @title = sprite("title_#{@kind}", 320, BAND_Y, 2)
      @viewport.sort_z
    end

    def plain(color, z)
      image = Image.new(320, 240)
      image.fill_rect(0, 0, 320, 240, color)
      @texture = Texture.new(320, 240)
      image.copy_to_bitmap(@texture)
      image.dispose
      sprite = Sprite.new(@viewport)
      sprite.bitmap = @texture
      sprite.z = z
      sprite.opacity = 0
      @sprites << sprite
      return sprite
    end

    def sprite(name, x, y, z)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = RPG::Cache.interface(StylesPLA.file(name))
      sprite.set_position(x, y)
      sprite.z = z
      sprite.opacity = 0
      @sprites << sprite
      return sprite
    end

    def ease(rate)
      return 1 - (1 - rate)**3
    end

    # @param count [Integer]
    # @yieldparam rate [Float]
    def frames(count)
      count.times do |index|
        yield((index + 1).to_f / count)
        locked = @visual.locking?
        @visual.lock unless locked
        @visual.scene_update_proc {}
        @visual.unlock unless locked
      end
    end

    def dispose
      @sprites.each { |sprite| sprite.dispose unless sprite.disposed? }
      @texture&.dispose unless @texture&.disposed?
      @viewport&.dispose unless @viewport&.disposed?
    end
  end

  # Cadre des effets du style choisi (au-dessus du choix de l'attaque)
  class InfoPanel < UI::SpriteStack
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, default_cache: :interface)
      @shown = false
      @background = add_sprite(0, 0, nil)
      @lines = []
      with_font(20) { 4.times { |i| @lines << add_text(6, 18 + i * 12, 216, 13, '', color: 9) } }
      self.visible = false
    end

    # @param kind [Symbol, nil] style montré (nil : caché)
    def show(kind)
      @shown = kind && StylesPLA.setting('show_info') && RPG::Cache.interface_exist?(StylesPLA.file("info_#{kind}")) ? true : false
      if @shown
        @background.set_bitmap(StylesPLA.file("info_#{kind}"), :interface)
        lines = StylesPLA::TEXTS[:"info_#{kind}"]
        @lines.each_with_index { |text, i| text.text = lines[i][StylesPLA.french? ? 0 : 1] }
      end
      self.visible = true
    end

    # @param value [Boolean]
    def visible=(value)
      super(value && @shown)
    end
  end
end

module BattleUI
  # Onglet « ACTION » : Strong / Agile
  module StylesPLATab
    private

    def sheet_for(kind, battler)
      return super unless StylesPLA::KINDS.include?(kind)

      name = StylesPLA.file("tab_#{kind}")
      return @sheets[name] if @sheets[name]
      return nil unless RPG::Cache.interface_exist?(name)

      rows = RPG::Cache.interface(name).height / Gimmicks::TAB_H
      return @sheets[name] = add_sprite(0, 0, name, 1, rows, type: SpriteSheet)
    end
  end
  Gimmicks::Tab.prepend(StylesPLATab)

  # Icône du style dans la boîte d'infos
  class InfoBar
    module StylesPLAIcon
      private

      def pj_refresh_gimmick_icon(pokemon)
        style = pokemon.is_a?(PFM::PokemonBattler) && pokemon.respond_to?(:pla_style) ? pokemon.pla_style : nil
        name = style && StylesPLA.file("icon_#{style}")
        return super unless @pj_gimmick_icon && name && RPG::Cache.interface_exist?(name)

        @pj_icon_on = true
        @pj_gimmick_icon.set_bitmap(name, :interface)
        @pj_gimmick_icon.src_rect.set(0, 0, @pj_gimmick_icon.bitmap.width, @pj_gimmick_icon.bitmap.height)
        @pj_gimmick_icon.visible = @stack.first&.visible ? true : false
      end
    end
    prepend StylesPLAIcon
  end

  class SkillChoice
    module StylesPLAChoice
      # Puissance / précision avec le style choisi (bande du bas de l'Interface Horizon)
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super
        pla_style_lines(pokemon)
      end

      private

      def create_sprites
        super
        # En haut à droite, sous la boîte d'infos de l'adversaire (devant son Pokémon)
        @pla_info = add_sprite(88, 42, nil, type: StylesPLA::InfoPanel)
      end

      def pj_refresh_tab
        super
        @pla_info&.show(StylesPLA::KINDS.include?(@pj_gimmick) ? @pj_gimmick : nil)
      end

      public

      # Le cadre des effets se cache pendant que la roue des mécaniques est ouverte
      def pj_open_wheel
        opened = super
        @pla_info&.show(nil) if opened
        return opened
      end

      private

      def pla_style_lines(pokemon)
        return unless @pj && pokemon && StylesPLA::KINDS.include?(@pj_gimmick) && respond_to?(:pj_lines=, true)

        move = pokemon.moveset[@index]
        return unless move && StylesPLA.battler_mastered?(pokemon, move)

        power = move.power
        power_text = power > 1 && !move.status? ? "#{power} > #{StylesPLA.styled_power(move, power, @pj_gimmick)}" : move.power_text
        accuracy = move.accuracy
        accuracy_text = @pj_gimmick == :strong && accuracy > 0 ? "#{accuracy} > #{StylesPLA.strong_accuracy(move, accuracy)}" : move.accuracy_text
        hint = BattleUI::PJ.text(:hint_skill)
        special = pj_special_hint(pokemon)
        hint = "#{BattleUI::PJ.text(:hint_short)}   #{special}" if special
        self.pj_lines = ["#{BattleUI::PJ.text(:power)} #{power_text}", "#{BattleUI::PJ.text(:accuracy)} #{accuracy_text}", hint]
      rescue StandardError => e
        log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend StylesPLAChoice

    # Petite graine sur les capacités maîtrisées
    class MoveButton
      module StylesPLAMastered
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          super
          move = pokemon.moveset[@index]
          @pla_on = move && StylesPLA.battler_mastered?(pokemon, move) ? true : false
          @pla_mastered.visible = @pla_on && visible ? true : false if @pla_mastered
        end

        # @param value [Boolean]
        def visible=(value)
          super
          @pla_mastered.visible = value && @pla_on ? true : false if @pla_mastered
        end

        private

        def create_sprites
          super
          @pla_on = false
          @pla_mastered = add_sprite(26, 11, StylesPLA.file('mastered'))
          @pla_mastered.visible = false
        end
      end
      prepend StylesPLAMastered
    end
  end

  # Capacités maîtrisées en gagnant un niveau pendant le combat
  class ExpDistribution
    module StylesPLALevel
      private

      def level_up_message(receiver, show_message: false)
        super
        original = receiver.original
        original.pj_update_mastery.each do |skill|
          scene.display_message_and_wait(StylesPLA.text(:mastered, original.given_name, skill.name))
        end
      rescue StandardError => e
        log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend StylesPLALevel
  end
end

# Résumé : petite graine à côté des capacités maîtrisées
module UI
  module SummaryPE
    module StylesPLASlot
      # @param skill [PFM::Skill, nil]
      def data=(skill)
        super
        pokemon = StylesPLA.summary_pokemon
        @pla_on = skill && pokemon.respond_to?(:pj_mastered?) && pokemon.pj_mastered?(skill.db_symbol) ? true : false
        @pla_mastered.visible = @pla_on && visible ? true : false if @pla_mastered
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @pla_mastered.visible = value && @pla_on ? true : false if @pla_mastered
      end

      private

      def create_slot_content
        super
        @pla_on = false
        @pla_mastered = add_sprite(47, 13, StylesPLA.file('mastered'))
        @pla_mastered.visible = false
      end
    end
    MoveSlot.prepend(StylesPLASlot) if const_defined?(:MoveSlot)
    SkillButton.prepend(StylesPLASlot) if const_defined?(:SkillButton)

    # Pokémon montré (les emplacements ne reçoivent que la capacité)
    module StylesPLAPage
      def data=(pokemon)
        StylesPLA.summary_pokemon = pokemon
        super
      end
    end
    MovesPage.prepend(StylesPLAPage) if const_defined?(:MovesPage)
    StatsPage.prepend(StylesPLAPage) if const_defined?(:StatsPage)
  end
end

module StylesPLA
  class << self
    # @return [PFM::Pokemon, nil] Pokémon du résumé
    attr_accessor :summary_pokemon
  end
end
