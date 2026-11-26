# encoding: utf-8
# Écran console : sur la carte, le jeu s'affiche dans un écran plus petit au centre d'une console portable, avec une
# manette de chaque côté (graphics/interface/console/console_<thème>_<L>x<H>.png, tools/console/build_console.py).
#
# Les manettes vont jusqu'aux bords de la fenêtre ; l'écran fait les 3 / 4 de la largeur, avec un rebord de 15 px en
# haut et en bas (640×360 -> 480×330 en (80, 15)). La carte y est à taille réelle (pixels nets, sans agrandissement) : on voit plus loin
# qu'en 320×240.
# La vue est décalée pour que le joueur soit au centre de l'écran, et le cadre (opaque autour de l'écran) cache le reste.
# Les images (pictures), la météo et les flashs suivent la carte. Les menus, combats et autres interfaces (320×240,
# script 10002 Ecran) sont agrandies pour remplir la hauteur de l'écran de la console (×1,375 en 640×360).
# La caméra de PSDK (centre du joueur) est recalculée pour la résolution, au cas où display_config garde les valeurs
# d'un ancien écran 320×240.
# Tailles d'écran prévues : 640×360, 640×480, 480×360 (une image de cadre par taille). L'état est écrit dans
# Ecran_diagnostic.log à chaque chargement de carte.
#
# Commandes (évents, Script) :
#   ecran_console(false)        cache la console (carte en plein écran, par exemple pour une cinématique)
#   ecran_console(true)         la remet ; ecran_console? : elle est affichée
#   ecran_console_theme('neon') thème : neon, gris, rouge, bleu, pastel, violet
module EcranConsole
  # Écran de la console : part de la largeur de la fenêtre (toute la hauteur) ; agrandissement de la carte (1 : pixels nets)
  ECRAN_PART = 0.75
  # rebord de la console au-dessus et au-dessous de l'écran (même valeur que BORD dans tools/console/build_console.py)
  BORD = 15
  ZOOM = 1
  # z du cadre : au-dessus de la carte, des images et de la météo (5000), sous les messages et menus
  Z = 5001
  THEMES = %w[neon gris rouge bleu pastel violet].freeze
  THEME_PAR_DEFAUT = 'neon'
  # false : la console n'est affichée qu'après ecran_console(true)
  ACTIVE_PAR_DEFAUT = true

  module_function

  # @return [Integer] largeur de la fenêtre du jeu (résolution)
  def largeur
    return Configs.display.game_resolution.x
  end

  def hauteur
    return Configs.display.game_resolution.y
  end

  # @return [Array(Integer, Integer, Integer, Integer)] écran de la console dans la fenêtre (x, y, largeur, hauteur)
  def ecran
    w = (largeur * ECRAN_PART).to_i
    h = hauteur - 2 * BORD
    return [(largeur - w) / 2, (hauteur - h) / 2, w, h]
  end

  # @return [Boolean] la console peut s'afficher (image du cadre présente pour cette taille d'écran)
  def possible?
    return RPG::Cache.interface_exist?(fichier)
  rescue StandardError
    return false
  end

  # @return [Boolean]
  def active?
    reglage = $user_data && $user_data[:pj_console]
    actif = reglage.nil? ? ACTIVE_PAR_DEFAUT : reglage
    return actif && possible?
  end

  def theme
    nom = $user_data && $user_data[:pj_console_theme]
    return THEMES.include?(nom) ? nom : THEME_PAR_DEFAUT
  end

  def fichier
    nom = "console/console_#{theme}_#{largeur}x#{hauteur}"
    # première version des images (640×360 seulement)
    ancien = "console/console_#{theme}"
    return ancien if largeur == 640 && hauteur == 360 && !RPG::Cache.interface_exist?(nom) && RPG::Cache.interface_exist?(ancien)

    return nom
  rescue StandardError
    return nom
  end

  # Écrit l'état de la console dans Ecran_diagnostic.log (aide si elle ne s'affiche pas)
  def diagnostic(viewports, cadre)
    lignes = ["#{Time.now} CONSOLE resolution=#{largeur}x#{hauteur} fichier=#{fichier} possible=#{possible?} " \
              "reglage=#{($user_data && $user_data[:pj_console]).inspect} active=#{active?} ecran=#{ecran.inspect} cadre=#{!cadre.nil?}"]
    viewports.each do |vp|
      reel = vp.instance_variable_get(:@pjc_reel)
      lignes << "  vp z=#{vp.z} reel=#{reel.x},#{reel.y},#{reel.width},#{reel.height} zoom=#{(vp.zoom_x rescue '?')} ox=#{vp.ox} oy=#{vp.oy}"
    end
    File.open('Ecran_diagnostic.log', 'a') { |f| f.puts(lignes) }
  rescue StandardError
    nil
  end

  # Applique l'état actuel aux viewports de la carte affichée
  def rafraichir
    spriteset = $scene.is_a?(::Scene_Map) ? $scene.instance_variable_get(:@spriteset) : nil
    spriteset&.pj_console_appliquer
  end

  # Viewport de la carte : rect réel changeable, rect logique toujours 640×360, origine corrigée pour le zoom
  module ViewportCarte
    def pj_console_init
      @pjc_reel = rect
      # toute la fenêtre, même si le viewport « main » a été créé plus petit
      @pjc_logique = Rect.new(0, 0, EcranConsole.largeur, EcranConsole.hauteur)
      @pjc_ox = 0
      @pjc_oy = 0
      @pjc_base = [0, 0]
      @pjc_set_ox = method(:ox=)
      @pjc_set_oy = method(:oy=)
      singleton_class.prepend(Methodes)
    end

    # @param actif [Boolean]
    def pj_console(actif)
      if actif
        # Le viewport garde toute la fenêtre (la carte en tuiles n'est dessinée que dans le rect du viewport) ; le zoom
        # se fait autour de son centre, et le cadre de la console, opaque autour de l'écran, cache ce qui dépasse.
        @pjc_reel.set(0, 0, @pjc_logique.width, @pjc_logique.height)
        self.zoom = ZOOM
        @pjc_base = [0, 0]
      else
        @pjc_reel.set(0, 0, @pjc_logique.width, @pjc_logique.height)
        self.zoom = 1
        @pjc_base = [0, 0]
      end
      @pjc_actif = actif
      self.ox = @pjc_ox
      self.oy = @pjc_oy
    end

    # Décale la vue (zoom) pour que le point (x, y) de la carte soit au centre de l'écran de la console
    def pj_console_viser(x, y)
      return unless @pjc_actif

      @pjc_base = [x, y]
      self.ox = @pjc_ox
      self.oy = @pjc_oy
    end

    module Methodes
      def rect
        return @pjc_logique
      end

      def ox
        return @pjc_ox
      end

      def oy
        return @pjc_oy
      end

      def ox=(value)
        @pjc_ox = value
        @pjc_set_ox.call(value + @pjc_base[0])
      end

      def oy=(value)
        @pjc_oy = value
        @pjc_set_oy.call(value + @pjc_base[1])
      end

      def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
        r = @pjc_reel
        return r.x <= mouse_x && mouse_x < r.x + r.width && r.y <= mouse_y && mouse_y < r.y + r.height
      end

      def translate_mouse_coords(mouse_x = Mouse.x, mouse_y = Mouse.y)
        return [mouse_x + ox, mouse_y + oy] unless @pjc_actif

        x, y, w, h = EcranConsole.ecran
        # point de la carte au centre de l'écran : (largeur / 2, hauteur / 2)
        lx = (mouse_x - (x + w / 2.0)) / ZOOM + @pjc_logique.width / 2.0 + @pjc_base[0]
        ly = (mouse_y - (y + h / 2.0)) / ZOOM + @pjc_logique.height / 2.0 + @pjc_base[1]
        return [lx.floor + ox, ly.floor + oy]
      end
    end
  end

  # Spriteset_Map : les trois viewports de la carte et le cadre de la console
  module Spriteset
    # La vue suit le joueur : il reste au centre de l'écran de la console
    def update
      super
      pj_console_suivre
    end

    def pj_console_suivre
      return unless @pjc_cadre_vp && $game_player

      zoom = Configs.display.tilemap_settings.character_tile_zoom.to_f
      w = EcranConsole.largeur
      h = EcranConsole.hauteur
      px = $game_player.screen_x * zoom
      py = $game_player.screen_y * zoom - 8
      # écart entre le joueur et le centre de la fenêtre (= centre de l'écran de la console)
      bx = (px - w / 2.0).round
      by = (py - h / 2.0).round
      @pjc_viewports.each { |vp| vp.pj_console_viser(bx, by) unless vp.disposed? }
    rescue StandardError
      nil
    end

    def init_viewports(viewport_type)
      super
      @pjc_viewports = [@viewport1, @viewport2, @viewport3].compact
      @pjc_viewports.each do |vp|
        vp.extend(ViewportCarte)
        vp.pj_console_init
      end
      pj_console_appliquer
    end

    def pj_console_appliquer
      actif = EcranConsole.active?
      @pjc_viewports&.each { |vp| vp.pj_console(actif) unless vp.disposed? }
      if actif
        pj_console_cadre
      else
        pj_console_sans_cadre
      end
      pj_console_suivre if actif
      EcranConsole.diagnostic(@pjc_viewports || [], @pjc_cadre)
    end

    # Captures de la carte (transition vers un combat…) : faites en plein écran, comme sans la console
    def snap_to_bitmaps
      return super unless @pjc_cadre_vp

      @pjc_viewports.each { |vp| vp.pj_console(false) }
      return super
    ensure
      @pjc_viewports.each { |vp| vp.pj_console(true) unless vp.disposed? } if @pjc_cadre_vp
    end

    def visible=(value)
      super
      @pjc_cadre_vp.visible = value if @pjc_cadre_vp && !@pjc_cadre_vp.disposed?
    end

    def dispose_viewport
      pj_console_sans_cadre
      super
    end

    private

    def pj_console_cadre
      if @pjc_cadre_vp.nil? || @pjc_cadre_vp.disposed?
        @pjc_cadre_vp = if defined?(::Ecran) && ::Ecran.respond_to?(:viewport_plein)
                          ::Ecran.viewport_plein(Z)
                        else
                          Viewport.create(0, 0, EcranConsole.largeur, EcranConsole.hauteur, Z)
                        end
        @pjc_cadre = Sprite.new(@pjc_cadre_vp)
      end
      @pjc_cadre.bitmap = RPG::Cache.interface(EcranConsole.fichier)
      @pjc_cadre.z = 1
      @pjc_cadre_vp.visible = @viewport1.visible
      @pjc_cadre_vp.sort_z if @pjc_cadre_vp.respond_to?(:sort_z)
    end

    def pj_console_sans_cadre
      @pjc_cadre&.dispose unless @pjc_cadre&.disposed?
      @pjc_cadre_vp&.dispose unless @pjc_cadre_vp&.disposed?
      @pjc_cadre = @pjc_cadre_vp = nil
    end
  end
end

Spriteset_Map.prepend(EcranConsole::Spriteset) if defined?(Spriteset_Map) && !Spriteset_Map.include?(EcranConsole::Spriteset)

class Interpreter
  # Affiche ou cache l'écran console sur la carte
  # @param actif [Boolean]
  def ecran_console(actif = true)
    $user_data[:pj_console] = actif ? true : false
    EcranConsole.rafraichir
  end

  # @return [Boolean]
  def ecran_console?
    return EcranConsole.active?
  end

  # @param nom [String] neon, gris, rouge, bleu, pastel ou violet
  def ecran_console_theme(nom)
    $user_data[:pj_console_theme] = nom.to_s
    EcranConsole.rafraichir
  end
end

# Caméra de PSDK : le joueur au centre de la fenêtre pour la résolution du jeu (Game_Player::CENTER_X / CENTER_Y sont
# lus une seule fois dans display_config ; des valeurs prévues pour 320×240 le mettaient dans le coin haut gauche)
if defined?(Game_Player) && Game_Player.const_defined?(:CENTER_X)
  pj_centre_x = (Configs.display.game_resolution.x / 2 - 8) * 8
  pj_centre_y = (Configs.display.game_resolution.y / 2 - 8) * 8
  if Game_Player::CENTER_X != pj_centre_x || Game_Player::CENTER_Y != pj_centre_y
    Game_Player.send(:remove_const, :CENTER_X)
    Game_Player.send(:remove_const, :CENTER_Y)
    Game_Player.const_set(:CENTER_X, pj_centre_x)
    Game_Player.const_set(:CENTER_Y, pj_centre_y)
  end
end
