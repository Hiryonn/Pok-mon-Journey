# Téléphone en bande sur le côté de l'écran (carte en exploration)
#
# - la carte occupe la partie gauche de l'écran (Ecran.carte_largeur x hauteur, proche de l'ancien 4:3) ;
# - la bande de droite (PANNEAU_LARGEUR) montre en permanence le téléphone du menu : coque, heure, applis de la première page ;
# - le menu (touche menu ou clic sur le téléphone) s'ouvre exactement à cet endroit, la carte reste visible à gauche.
# Pour revenir à l'ancien affichage : PANNEAU_TELEPHONE = false (puis relancer le jeu).
module Ecran
  # Active la bande téléphone (nécessite le plugin pokesmart et un écran plus grand que 320x240)
  PANNEAU_TELEPHONE = true
  # Largeur réelle de la bande (la coque du téléphone fait 122 x échelle 1,5 = 183 px)
  PANNEAU_LARGEUR = 184
  # z du viewport de la bande (entre les images de la carte et la météo)
  PANNEAU_Z = 4000

  module_function

  # @return [Boolean] vrai si la carte est réduite pour laisser la place au téléphone
  def panneau_actif?
    return false unless PANNEAU_TELEPHONE && grand?
    # écran console (script 10006) : le téléphone serait caché par la console
    return false if defined?(::EcranConsole) && ::EcranConsole.active?

    return defined?(::UI::PokeSmart::Phone) && ::UI::PokeSmart::ENABLED ? true : false
  end

  # @return [Integer] largeur réelle de la carte
  def carte_largeur
    return panneau_actif? ? largeur - PANNEAU_LARGEUR : largeur
  end

  # @return [Integer] x (repère logique du cadre) du bord gauche de la bande
  def panneau_x_logique
    return logique_gauche + (carte_largeur / echelle).round
  end

  # @param message [String]
  def journal_panneau(message)
    File.open('Ecran_diagnostic.log', 'a') { |f| f.puts("#{Time.now} PANNEAU #{message}") }
  rescue StandardError
    nil
  end

  # Le téléphone affiché en permanence sur la carte
  class Panneau
    # @return [Viewport]
    attr_reader :viewport

    def initialize
      ps = ::UI::PokeSmart
      @viewport = Ecran.contourner { Viewport.create(Ecran.carte_largeur, 0, PANNEAU_LARGEUR, Ecran.hauteur, PANNEAU_Z) }
      Ecran.adapter(@viewport, 0, 0, 122, Ecran::BASE_HAUTEUR)
      @phone = ps::Phone.new(@viewport)
      @phone.move(-@phone.x, 0)
      create_buttons
    end

    # Heure, batterie et clic sur le téléphone
    def update
      return if @viewport.disposed?

      @phone.update
      update_souris
    end

    # @param value [Boolean]
    def visible=(value)
      @viewport.visible = value unless @viewport.disposed?
    end

    def dispose
      @viewport.dispose unless @viewport.disposed?
    end

    private

    # Même liste d'applis que le menu (mêmes règles de tri), première page et barre du bas seulement
    def create_buttons
      ps = ::UI::PokeSmart
      menu = GamePlay::Menu.allocate
      menu.send(:init_conditions)
      menu.send(:init_indexes)
      indexes = menu.instance_variable_get(:@image_indexes)
      gx, gy = @phone.theme[:grid]
      cx, cy = @phone.theme[:cell]
      dock_y = ps.home_layout(@phone.theme)[:dock]
      dock_count = [ps::DOCK_APPS, ps::COLUMNS, indexes.size - 1].min.clamp(0, ps::COLUMNS)
      dock_start = indexes.size - dock_count
      @menu_indexes = []
      @buttons = []
      indexes.each_with_index do |real_index, i|
        if i >= dock_start
          col = i - dock_start + (ps::COLUMNS - dock_count) / 2
          x = @phone.x + gx + col * cx
          y = @phone.y + dock_y
        else
          next if i >= ps::APPS_PER_PAGE

          x = @phone.x + gx + (i % ps::COLUMNS) * cx
          y = @phone.y + gy + (i / ps::COLUMNS) * cy
        end
        @buttons << ps::AppButton.new(@viewport, real_index, x, y)
        @menu_indexes << i
      end
      pages = [(dock_start + ps::APPS_PER_PAGE - 1) / ps::APPS_PER_PAGE, 1].max
      @phone.set_pages(pages, 0)
      @phone.dock_visible = dock_start > 0 && dock_count > 0
    end

    # Un clic sur le téléphone ouvre le menu (sur l'appli cliquée)
    def update_souris
      return unless Mouse.trigger?(:LEFT) && Mouse.x >= Ecran.carte_largeur
      return if $game_system.map_interpreter.running? || $game_system.menu_disabled || $game_player.moving? || $game_player.sliding?

      index = @buttons.index(&:simple_mouse_in?)
      $game_temp.last_menu_index = @menu_indexes[index] if index
      $game_temp.menu_calling = true
      $game_temp.menu_beep = true
    end
  end

  # Carte réduite + bande téléphone (Spriteset_Map)
  module CartePanneau
    # @param zone [Integer, nil]
    def initialize(*)
      @ecran_panneau = nil
      super
    end

    # @return [Ecran::Panneau, nil]
    attr_reader :ecran_panneau

    def update
      super
      @ecran_panneau&.update
    end

    def visible=(value)
      super
      @ecran_panneau&.visible = value
    end

    def dispose(*)
      resultat = super
      if disposed? && @ecran_panneau
        @ecran_panneau.dispose
        @ecran_panneau = nil
      end
      return resultat
    end

    private

    def init_viewports(viewport_type)
      super
      return unless Ecran.panneau_actif?

      [@viewport1, @viewport3].each { |vp| vp.rect.width = Ecran.carte_largeur }
      @ecran_panneau = Ecran::Panneau.new
    rescue StandardError => e
      Ecran.journal_panneau("#{e.class} #{e.message} #{e.backtrace&.first(3)&.join(' | ')}")
      @ecran_panneau = nil
    end
  end

  # Menu ouvert depuis la carte : le téléphone se pose sur la bande, la carte reste visible
  module MenuPanneau
    # @return [Boolean]
    def docke?
      return Ecran.panneau_actif? && @__last_scene.is_a?(::Scene_Map) && @__last_scene.spriteset&.ecran_panneau ? true : false
    end

    # Pas de fond noir (la carte reste visible)
    # @return [Boolean]
    def sans_fond?
      return docke?
    end

    private

    def create_background
      super
      @background.visible = false if docke? && @background
    end

    # La carte reste affichée (pas de flou, la bande est déjà à sa place : pas de glissement)
    def update_entering_animation
      super
      @__last_scene.spriteset.visible = true if docke?
    end

    def init_entering
      return super unless docke?
    end

    def create_entering_animation
      return super unless docke?

      return Yuki::Animation.wait(0.05).start
    end

    def create_quitting_animation
      return super unless docke?

      @buttons.each { |button| button.selected = false }
      return Yuki::Animation.wait(0.05).start
    end
  end

  # La coque se pose sur la bande quand le menu est ouvert depuis la carte
  module PhonePanneau
    def initialize(viewport)
      super
      scene = Ecran.scene_active
      return unless scene.respond_to?(:docke?) && scene.docke? && Ecran.cadre?(viewport)

      move(Ecran.panneau_x_logique - x, 0)
    end
  end
end

if Ecran.panneau_actif?
  # La carte est centrée sur sa zone réduite (valeur d'origine : (320 - 8) * 8 pour 640 de large)
  centre_x = (Ecran.carte_largeur / 2 - 8) * 8
  Game_Player.send(:remove_const, :CENTER_X)
  Game_Player.const_set(:CENTER_X, centre_x)
  Spriteset_Map.prepend(Ecran::CartePanneau) unless Spriteset_Map.include?(Ecran::CartePanneau)
  GamePlay::Menu.prepend(Ecran::MenuPanneau) unless GamePlay::Menu.include?(Ecran::MenuPanneau)
  UI::PokeSmart::Phone.prepend(Ecran::PhonePanneau) unless UI::PokeSmart::Phone.include?(Ecran::PhonePanneau)
end
