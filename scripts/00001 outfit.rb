# Système de tenues du héros avec interface d'aperçu (PSDK / Pokémon Studio)
# À placer dans le dossier de scripts du projet, chargé après les scripts de base.
#
# Ouvrir le menu depuis un événement (commande « Script ») :
#   call_scene(Outfit::Scene)
# Changer de tenue directement, sans menu :
#   Outfit.change(1)

module Outfit
  # Variable du jeu qui mémorise la tenue choisie (prends une variable libre)
  VARIABLE_ID = 100

  # id => infos de la tenue
  #   name     : nom affiché dans le menu
  #   set      : préfixe des sprites du héros (ex. 'player_m' => player_m_walk.png, ...)
  #   walk     : feuille de marche utilisée pour l'animation d'aperçu (graphics/characters/)
  #   portrait : image affichée en grand (graphics/battlers/), nil si tu n'en as pas
  LIST = {
    0 => { name: 'Tenue rouge', set: 'player_m', walk: 'player_m_walk', portrait: 'Felix' },
    1 => { name: 'Tenue bleue', set: 'player_m_blue', walk: 'player_m_blue_walk', portrait: nil }
  }

  module_function

  # Tenue actuellement choisie (retombe sur 0 si l'id est inconnu)
  def current
    id = $game_variables[VARIABLE_ID]
    LIST.key?(id) ? id : 0
  end

  # Change de tenue et l'applique tout de suite
  def change(id)
    return false unless LIST.key?(id)
    $game_variables[VARIABLE_ID] = id
    apply
    true
  end

  # Applique la tenue courante au héros
  def apply
    return unless $game_player
    $game_player.set_appearance_set(LIST[current][:set])
  end

  # Scène de choix avec aperçu : gauche/droite = changer, A = valider, B = retour
  class Scene < GamePlay::Base
    def initialize
      super
      @ids = LIST.keys.sort
      @index = @ids.index(Outfit.current) || 0
      @frame = 0
      @tick = 0
    end

    def create_graphics
      super
      @viewport ||= Viewport.create(:main, 10_000)
      create_background
      @portrait = Sprite.new(@viewport)
      @portrait.set_position(16, 16)
      @portrait.zoom = 1.75
      @walk = Sprite.new(@viewport)
      @walk.set_position(204, 36)
      @walk.zoom = 3
      @text = Sprite.new(@viewport)
      @text.bitmap = Bitmap.new(320, 240)
      refresh
    end

    def create_background
      @bg = Sprite.new(@viewport)
      @bg.bitmap = Bitmap.new(320, 240)
      @bg.bitmap.fill_rect(0, 0, 320, 240, Color.new(30, 34, 48))
      @bg.bitmap.fill_rect(12, 12, 148, 170, Color.new(55, 62, 86))
      @bg.bitmap.fill_rect(172, 12, 136, 170, Color.new(55, 62, 86))
      @bg.bitmap.fill_rect(12, 192, 296, 36, Color.new(55, 62, 86))
    end

    def update
      super
      update_walk
      if Input.trigger?(:LEFT)
        move(-1)
      elsif Input.trigger?(:RIGHT)
        move(1)
      elsif Input.trigger?(:A)
        Outfit.change(@ids[@index])
        @running = false
      elsif Input.trigger?(:B)
        @running = false
      end
    end

    def dispose
      [@bg, @text].each { |sprite| sprite&.bitmap&.dispose }
      [@bg, @portrait, @walk, @text].each { |sprite| sprite&.dispose }
      super if defined?(super)
    end

    private

    def move(delta)
      @index = (@index + delta) % @ids.size
      refresh
    end

    # Fait défiler les 4 images de la ligne « face » de la feuille de marche
    def update_walk
      @tick += 1
      return unless (@tick % 10).zero?
      @frame = (@frame + 1) % 4
      apply_walk_rect
    end

    def apply_walk_rect
      bmp = @walk.bitmap
      return unless bmp
      frame_w = bmp.width / 4
      frame_h = bmp.height / 4
      @walk.src_rect.set(@frame * frame_w, 0, frame_w, frame_h)
    end

    def refresh
      data = LIST[@ids[@index]]
      @walk.bitmap = RPG::Cache.character(data[:walk], 0)
      @frame = 0
      apply_walk_rect
      if data[:portrait]
        @portrait.bitmap = RPG::Cache.battler(data[:portrait], 0)
        @portrait.visible = true
      else
        @portrait.visible = false
      end
      draw_texts(data)
    end

    def draw_texts(data)
      @text.bitmap&.dispose
      bmp = Bitmap.new(320, 240)
      @text.bitmap = bmp
      bmp.font.size = 16
      equipped = @ids[@index] == Outfit.current ? ' (équipée)' : ''
      bmp.draw_text(172, 150, 136, 20, "#{@index + 1} / #{@ids.size}", 1)
      bmp.draw_text(12, 196, 296, 18, data[:name] + equipped, 1)
      bmp.draw_text(12, 210, 296, 18, '< >  Changer     A  Choisir     B  Retour', 1)
    end
  end
end

# Réapplique la tenue après chaque changement de map (donc aussi après un chargement)
Scheduler.add_proc(:on_warp_end, :any, 'Outfit apply', 1000) { Outfit.apply }
