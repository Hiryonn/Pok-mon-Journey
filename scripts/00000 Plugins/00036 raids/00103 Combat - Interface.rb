# Raids : interface du combat (barre du boss en haut avec le bouclier, compteurs de tours et de K.O., niveau
# d'encouragement, boss au centre et plus grand) et choix de l'encouragement (à la place de la Fuite)
module Raids
  # Barre du boss, bouclier, compteurs
  class BattleHud < UI::SpriteStack
    WHITE = 10
    BOSS_ZOOM = 1.25

    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    def initialize(viewport, scene)
      super(viewport)
      @scene = scene
      @rules = Raids.rules_of(scene.logic)
      @boss = Raids.boss_of(scene.logic)
      add_sprite(0, 0, Raids.file('battle/boss_bar'))
      @name = add_text(8, 1, 200, 16, '', color: WHITE)
      @bar = push_sprite(UI::Bar.new(viewport, 67, 18, RPG::Cache.interface(Raids.file('battle/hp_long')), 238, 3, 0, 0, 6))
      @shields = Array.new(8) do |i|
        cell = add_sprite(8 + i * 12, 20, Raids.file('battle/shield'))
        cell.src_rect.set(0, 0, 13, 7)
        cell
      end
      @turn_box = add_sprite(4, 40, Raids.file('battle/counter'))
      @turn_icon = add_sprite(8, 42, Raids.file('battle/counter_icons'))
      @turn_icon.src_rect.set(0, 0, 11, 11)
      @turns = add_text(20, 40, 30, 15, '', 1, color: WHITE)
      @ko_box = add_sprite(4, 57, Raids.file('battle/counter'))
      @ko_icon = add_sprite(8, 59, Raids.file('battle/counter_icons'))
      @ko_icon.src_rect.set(0, 11, 11, 11)
      @kos = add_text(20, 57, 30, 15, '', 1, color: WHITE)
      @pips = Array.new(3) do |i|
        pip = add_sprite(8 + i * 10, 75, Raids.file('battle/cheer_pips'))
        pip.src_rect.set(0, 8, 8, 8)
        pip
      end
      @flash = Sprite.new(viewport)
      @flash.bitmap = RPG::Cache.interface(Raids.file("battle/flash_#{@rules.style}"))
      @flash.opacity = 0
      @flash.z = 10_000
      self.z = 9000
      refresh
    end

    def refresh
      return if disposed?

      @name.text = @boss ? format('%s  %s', @boss.given_name, '★' * @rules.rank.to_i) : ''
      @bar.rate = @boss ? @boss.hp_rate : 0
      shield = @rules.shield.to_i
      @shields.each_with_index do |cell, i|
        cell.visible = shield > 0 && i < @rules.shield_hp.to_i
        cell.src_rect.y = i < shield ? 0 : 7
      end
      @turns.text = @rules.turn_count.to_s
      @kos.text = @rules.ko_count.to_s
      @ko_box.visible = @ko_icon.visible = @kos.visible = @rules.ko_count.to_i >= 0
      level = @rules.cheer_level.to_i
      @pips.each_with_index do |pip, i|
        pip.visible = @rules.cheers ? true : false
        pip.src_rect.y = i < level ? 0 : 8
      end
    end

    def update
      return if disposed?

      @bar.rate = @boss.hp_rate if @boss
      @flash.opacity -= 12 if @flash.opacity > 0
    end

    # Éclair de couleur (action en plus du boss, bouclier)
    def flash
      @flash.opacity = 200
      Audio.se_play('audio/se/moves/reflect') rescue nil
      12.times do
        Graphics.update
        update
      end
    end

    def dispose
      @flash.dispose unless @flash.disposed?
      super
    end
  end

  # Choix de l'encouragement (4 lignes : attaque, défense, soin, encouragement du style)
  class CheerChoice < UI::SpriteStack
    WHITE = 10
    DARK = 0

    # @param viewport [Viewport]
    # @param rules [Rules]
    def initialize(viewport, rules)
      super(viewport, 62, 34)
      @rules = rules
      @index = 0
      add_sprite(0, 0, Raids.file('battle/cheer_panel'))
      add_text(8, 2, 120, 16, Raids.t('ENCOURAGER', 'CHEER'), color: WHITE)
      @level_pips = Array.new(3) do |i|
        pip = add_sprite(160 + i * 10, 6, Raids.file('battle/cheer_pips'))
        pip.src_rect.set(0, rules.cheer_level.to_i > i ? 0 : 8, 8, 8)
        pip
      end
      @rows = Raids::CHEERS.map.with_index do |cheer, i|
        row = add_sprite(6, 22 + i * 18, Raids.file('battle/cheer_row'))
        row.src_rect.set(0, 0, 184, 18)
        icon = add_sprite(10, 23 + i * 18, Raids.file('battle/cheer_icons'))
        icon.src_rect.set(0, Raids.cheer_icon(cheer, rules) * 16, 16, 16)
        text = add_text(30, 22 + i * 18, 150, 16, Raids.cheer_name(cheer, rules), color: WHITE)
        [row, text, cheer]
      end
      @desc = add_text(8, 96, 182, 16, '', color: WHITE)
      @desc2 = add_text(8, 110, 182, 16, '', color: WHITE)
      self.z = 9500
      refresh
    end

    # @return [Symbol, nil] encouragement choisi
    def run
      loop do
        Graphics.update
        if Input.trigger?(:UP)
          @index = (@index - 1) % @rows.size
          $game_system.se_play($data_system.cursor_se)
          refresh
        elsif Input.trigger?(:DOWN)
          @index = (@index + 1) % @rows.size
          $game_system.se_play($data_system.cursor_se)
          refresh
        elsif Input.trigger?(:A)
          cheer = @rows[@index][2]
          if Raids.cheer_usable?(cheer, @rules)
            $game_system.se_play($data_system.decision_se)
            return cheer
          end

          $game_system.se_play($data_system.buzzer_se)
        elsif Input.trigger?(:B)
          $game_system.se_play($data_system.cancel_se)
          return nil
        end
      end
    end

    private

    def refresh
      @rows.each_with_index do |(row, text, cheer), i|
        row.src_rect.y = i == @index ? 18 : 0
        text.load_color(Raids.cheer_usable?(cheer, @rules) ? WHITE : DARK)
      end
      lines = Raids.cheer_description(@rows[@index][2], @rules)
      @desc.text = lines[0].to_s
      @desc2.text = lines[1].to_s
    end
  end
end

module Battle
  class Visual
    # @return [Raids::BattleHud, nil]
    attr_reader :pj_raid_hud

    # Début du raid : interface et boss mis en avant
    def pj_raid_start
      @pj_raid_hud ||= Raids::BattleHud.new(@viewport, @scene)
      boss = Raids.boss_of(@scene.logic)
      hide_info_bar(boss) if boss
    end

    module RaidsVisual
      def update
        super
        @pj_raid_hud&.update
      end

      def dispose
        @pj_raid_hud&.dispose
        super
      end
    end
    prepend RaidsVisual
  end

  class Scene
    private

    # Encouragement : remplace l'action du Pokémon
    def pj_raid_cheer_choice
      rules = Raids.rules_of(@logic)
      user = @logic.battler(0, @player_actions.size)
      if !rules.cheers || rules.cheer_used
        display_message_and_wait(rules.cheers ? Raids.t('Vous avez déjà encouragé ce tour-ci.', 'You already cheered this round.') : Raids.t('Impossible d’encourager dans ce combat.', 'Cheers can’t be used in this battle.'))
        return @next_update = :player_action_choice
      end
      ui = Raids::CheerChoice.new(@visual.viewport, rules)
      cheer = ui.run
      ui.dispose
      return @next_update = :player_action_choice unless cheer

      rules.cheer_used = true
      @player_actions << Actions::PJRaidCheer.new(self, user, cheer)
      @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
    end
  end
end

module BattleUI
  # La barre d'infos du boss est remplacée par celle du haut
  class InfoBar
    module RaidsHide
      def visible=(value)
        value = false if value && @pokemon && @scene && Raids.boss?(@pokemon, @scene.logic)
        super(value)
      end
    end
    prepend RaidsHide
  end

  # Boss : au centre et plus grand
  class PokemonSprite
    module RaidsBoss
      def sprite_zoom
        return super unless @pokemon && @scene && Raids.boss?(@pokemon, @scene.logic)

        return super * Raids::BattleHud::BOSS_ZOOM
      end

      private

      def sprite_position
        return super unless @pokemon && @scene && Raids.boss?(@pokemon, @scene.logic)

        x, y = base_position_v1
        return x - 8, y + 4
      end
    end
    prepend RaidsBoss
  end
end
