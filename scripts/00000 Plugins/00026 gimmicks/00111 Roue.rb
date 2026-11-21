# Gimmicks : roue des mécaniques
#
# Pendant le choix de l'attaque, Y ouvre la roue (style de l'interface Horizon) : toutes les mécaniques possibles pour
# le Pokémon (Méga-Évolution, capacité Z, Dynamax, Téracristal, styles de combat…) sont disposées en cercle (icône et
# nom court) autour d'un cadre « ACTION » qui donne le nom de celle sous le curseur. On la désigne avec les flèches
# (en pointant : haut, bas, gauche, droite et diagonales) ou la souris ; A la choisit pour ce tour (A sur la mécanique
# déjà choisie l'annule), B ou Y referme la roue.
# Images : graphics/interface/gimmicks/wheel (tools/gimmicks/build_wheel.py)
module Gimmicks
  class Wheel < UI::SpriteStack
    # Centre et rayons de l'ellipse où sont posées les cases
    CX = 160
    CY = 100
    RX = 120
    RY = 64
    # Nombre maximal de mécaniques affichées
    MAX = 8
    SLOT_W = 86
    SLOT_H = 22
    HUB_W = 120
    HUB_H = 78
    WHITE = 9
    DARK = 0

    # @return [Integer] mécanique sous le curseur
    attr_reader :index

    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, default_cache: :interface)
      @open = false
      @kinds = []
      @index = 0
      @positions = []
      add_sprite(0, 0, Gimmicks.file('wheel/dim'))
      add_sprite(CX - RX - 6, CY - RY - 6, Gimmicks.file('wheel/ring'))
      hx = CX - HUB_W / 2
      hy = CY - HUB_H / 2
      add_sprite(hx, hy, Gimmicks.file('wheel/hub'))
      add_text(hx, hy + 1, HUB_W, 16, Gimmicks.text(:wheel_short).upcase, 1, color: WHITE)
      @name = add_text(hx + 4, hy + 24, HUB_W - 8, 16, '', 1, color: DARK)
      with_font(20) do
        @help1 = add_text(hx + 4, hy + 48, HUB_W - 8, 13, '', 1, color: DARK)
        @help2 = add_text(hx + 4, hy + 60, HUB_W - 8, 13, '', 1, color: DARK)
      end
      @slots = Array.new(MAX) do
        background = add_sprite(0, 0, Gimmicks.file('wheel/slot'), 1, 2, type: SpriteSheet)
        icon = add_sprite(0, 0, nil)
        text = add_text(0, 0, SLOT_W - 26, 16, '', 0, color: WHITE)
        [background, icon, text]
      end
      @check = add_sprite(0, 0, Gimmicks.file('wheel/check'))
      self.visible = false
    end

    # @return [Boolean]
    def open?
      return @open
    end

    # @param kinds [Array<Symbol>] mécaniques possibles
    # @param chosen [Symbol, nil] mécanique déjà choisie pour ce tour
    # @param battler [PFM::PokemonBattler]
    def open(kinds, chosen, battler)
      @kinds = kinds.first(MAX)
      @chosen = chosen
      @battler = battler
      @index = @kinds.index(chosen) || 0
      @last_dir = nil
      layout
      @open = true
      self.visible = true
      refresh
    end

    def close
      @open = false
      self.visible = false
    end

    # @return [Symbol, nil] mécanique sous le curseur
    def kind
      return @kinds[@index]
    end

    # @return [Symbol, nil] :move (curseur déplacé), :choose (A), :back (B / Y)
    def update_input
      return :back if Input.trigger?(:B) || Input.trigger?(:Y)
      return :choose if Input.trigger?(:A)

      target = mouse_target
      if target && Mouse.trigger?(:LEFT)
        @index = target
        refresh
        return :choose
      end
      target ||= direction_target
      return nil if target.nil? || target == @index

      @index = target
      refresh
      return :move
    end

    # @param value [Boolean]
    def visible=(value)
      super(value && @open)
      @slots&.each_with_index { |slot, i| slot.each { |sprite| sprite.visible = false } if i >= @kinds.size }
      @check.visible = false if @check && (!@open || !@kinds.include?(@chosen))
    end

    private

    # Positions sur l'ellipse : en haut puis dans le sens des aiguilles d'une montre (2 mécaniques : gauche et droite)
    def layout
      count = @kinds.size
      start = count == 2 ? 180 : -90
      @angles = Array.new(count) { |i| (start + 360.0 * i / count) % 360 }
      @positions = @angles.map do |angle|
        rad = angle * Math::PI / 180
        x = ((CX + RX * Math.cos(rad)).round - SLOT_W / 2).clamp(2, 318 - SLOT_W)
        [x, (CY + RY * Math.sin(rad)).round - SLOT_H / 2]
      end
    end

    def refresh
      @kinds.each_with_index do |kind, i|
        background, icon, text = @slots[i]
        x, y = @positions[i]
        background.set_position(@x + x, @y + y)
        background.sy = i == @index ? 1 : 0
        icon.set_bitmap(Gimmicks.wheel_icon(kind, @battler), :interface)
        icon.set_position(@x + x + 3 + (16 - icon.width) / 2, @y + y + 3 + (16 - icon.height) / 2)
        text.set_position(@x + x + 23, @y + y + 2 - Text::Util::FOY)
        text.text = Gimmicks.wheel_short(kind, @battler)
      end
      if (chosen = @kinds.index(@chosen))
        cx, cy = @positions[chosen]
        @check.set_position(@x + cx + SLOT_W - 8, @y + cy - 5)
        @check.visible = true
      else
        @check.visible = false
      end
      @name.text = Gimmicks.wheel_name(kind, @battler)
      @help1.text = Gimmicks.text(kind == @chosen ? :wheel_cancel : :wheel_choose)
      @help2.text = Gimmicks.text(:wheel_back)
    end

    # Flèches : la mécanique la plus proche de la direction pointée
    def direction_target
      dx = (Input.press?(:RIGHT) ? 1 : 0) - (Input.press?(:LEFT) ? 1 : 0)
      dy = (Input.press?(:DOWN) ? 1 : 0) - (Input.press?(:UP) ? 1 : 0)
      dir = [dx, dy]
      return @last_dir = nil if dir == [0, 0]
      return nil if dir == @last_dir

      @last_dir = dir
      angle = Math.atan2(dy * RY, dx * RX) * 180 / Math::PI
      return @angles.each_index.min_by do |i|
        diff = (@angles[i] - angle).abs % 360
        diff > 180 ? 360 - diff : diff
      end
    end

    # @return [Integer, nil] mécanique sous la souris
    def mouse_target
      return nil unless Mouse.moved || Mouse.trigger?(:LEFT)

      mx = Mouse.x - @x
      my = Mouse.y - @y
      return @positions.index { |(x, y)| mx.between?(x, x + SLOT_W - 1) && my.between?(y, y + SLOT_H - 1) }
    rescue StandardError
      return nil
    end
  end

  module_function

  # Nom complet d'une mécanique dans la roue
  # @param kind [Symbol]
  # @param battler [PFM::PokemonBattler]
  # @return [String]
  def wheel_name(kind, battler)
    return '' unless kind
    return Gimmicks.french? ? 'Ultra-Explosion' : 'Ultra Burst' if kind == :zmove && Gimmicks.ultra?(battler)

    return Gimmicks.text(kind)
  rescue StandardError
    return kind.to_s
  end

  # Nom court dans une case de la roue
  # @param kind [Symbol]
  # @param battler [PFM::PokemonBattler]
  # @return [String]
  def wheel_short(kind, battler)
    return 'Ultra' if kind == :zmove && Gimmicks.ultra?(battler)

    return Gimmicks.text(:"#{kind}_short")
  rescue StandardError
    return kind.to_s
  end

  # Icône 16 x 16 d'une mécanique (graphics/interface)
  # @param kind [Symbol]
  # @param battler [PFM::PokemonBattler]
  # @return [String]
  def wheel_icon(kind, battler)
    kind = :ultra if kind == :zmove && Gimmicks.ultra?(battler)
    return Gimmicks.file("wheel/icon_#{kind}")
  end

  def french?
    return $options&.language == 'fr'
  end
end

module BattleUI
  class SkillChoice
    module PJGimmickWheel
      # Roue ouverte : elle prend toutes les touches
      def update
        return super unless @pj_wheel&.open?

        @animation_handler.update
        case @pj_wheel.update_input
        when :move then play_cursor_se
        when :choose then pj_wheel_choose
        when :back
          play_cancel_se
          @pj_wheel.close
          pj_refresh_tab
        end
      end

      # Y : ouvre la roue
      # @return [Boolean] au moins une mécanique possible
      def pj_open_wheel
        return false if @pj_wheel.nil? || pj_options.empty?

        @pj_wheel.open(pj_options, @pj_gimmick, @pokemon)
        return true
      end

      def reset(pokemon)
        @pj_wheel&.close
        super
      end

      private

      def create_sprites
        super
        @pj_wheel = add_sprite(0, 0, nil, type: Gimmicks::Wheel)
      end

      # A : choisit la mécanique (ou l'annule si elle l'était déjà)
      def pj_wheel_choose
        kind = @pj_wheel.kind
        kind = nil if kind == @pj_gimmick
        @pj_gimmick = kind
        @mega_enabled = kind == :mega
        @pj_wheel.close
        self.data = @pokemon if @pokemon
        pj_refresh_tab
        kind ? play_decision_se : play_cancel_se
      end
    end
    prepend PJGimmickWheel
  end
end
