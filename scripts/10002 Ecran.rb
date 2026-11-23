# encoding: utf-8
# Écran 640×360 : les interfaces écrites pour 320×240 sont affichées dans un cadre agrandi (zoom 1,5 -> 480×360, soit des
# pixels de 3×3 dans une fenêtre 1280×720), centré à l'écran. Les scènes voient toujours un écran logique de 320×240
# (viewport.rect, positions, messages) : rien à changer dans leur code. Avec un écran de 320×240, rien ne change.
#
# Réglages nécessaires : Data/Viewport.json (viewport « main » = taille de l'écran) et display_config.json (gameResolution).
#
#   Viewport.create(:frame, z)          viewport de la taille d'une ancienne interface (320×240 logiques), centré, zoomé
#   Ecran.viewport(z, fond: true)       idem, avec un fond noir sur tout l'écran (supprimé avec le viewport)
#   Ecran.placer(vp, x, y, w, h)        place un viewport de cadre aux coordonnées logiques 320×240 (comme l'ancien rect.set)
#   Ecran.largeur / Ecran.hauteur       taille réelle de l'écran
#
# Toutes les scènes GamePlay::Base sauf la carte (menus, sac, équipe, Pokédex, combat, concours…) sont cadrées
# automatiquement : tout Viewport.create(:main, z) et Viewport.create(x, y, w, h, z) fait pendant la scène est converti.
# Une scène refaite en pleine largeur répond « true » à plein_ecran? (ou définit sa propre méthode create_viewport).
# Une scène peut aussi répondre « true » à origine_gauche? : elle reste cadrée (zoom) mais son point (0, 0) est le coin haut gauche
# de TOUT l'écran (largeur logique : Ecran.logique_largeur). Les rects logiques des viewports numériques suivent le vrai rect.
module Ecran
  BASE_LARGEUR = 320
  BASE_HAUTEUR = 240
  # Z du fond noir placé derrière le cadre
  FOND_Z = -1
  # Agrandissement maximal du cadre (1 = pas d'agrandissement). Mettre 1 pour désactiver le zoom si l'affichage pose problème.
  ZOOM_MAX = 3

  module_function

  # @return [Integer] largeur de l'écran
  def largeur
    return Configs.display.game_resolution.x
  end

  # @return [Integer] hauteur de l'écran
  def hauteur
    return Configs.display.game_resolution.y
  end

  # @return [Boolean] vrai si l'écran est plus grand qu'une ancienne interface
  def grand?
    return largeur > BASE_LARGEUR || hauteur > BASE_HAUTEUR
  end

  # @return [Float] agrandissement du cadre (écran 640×360 -> 1,5)
  def echelle
    return 1 unless grand?

    return [[largeur / BASE_LARGEUR.to_f, hauteur / BASE_HAUTEUR.to_f].min, ZOOM_MAX, 1].sort[1]
  end

  # @return [Integer] largeur réelle du cadre
  def cadre_largeur
    return (BASE_LARGEUR * echelle).round
  end

  # @return [Integer] hauteur réelle du cadre
  def cadre_hauteur
    return (BASE_HAUTEUR * echelle).round
  end

  # @return [Integer]
  def decalage_x
    return [(largeur - cadre_largeur) / 2, 0].max
  end

  # @return [Integer]
  def decalage_y
    return [(hauteur - cadre_hauteur) / 2, 0].max
  end

  # Déclare le viewport :frame (appelé avant chaque usage, la configuration d'écran pouvant être lue après ce script)
  def configurer
    # Le viewport de cadre couvre tout l'écran (rien n'est rogné) ; l'interface 320x240 y est centrée par l'origine de base
    Viewport::CONFIGS[:frame] = { x: 0, y: 0, width: largeur, height: hauteur }
  end

  # @return [Integer] x logique (repère 320x240) du bord gauche de l'écran dans un viewport de cadre
  def logique_gauche
    return (-((largeur - BASE_LARGEUR * echelle) / 2.0) / echelle).floor
  end

  # @return [Integer] largeur logique (repère 320x240) de tout l'écran dans un viewport de cadre
  def logique_largeur
    return (largeur / echelle).ceil + 2
  end

  # @param vp [Viewport, nil]
  # @return [Integer] x logique du bord gauche de l'écran dans ce viewport (0 si l'origine est à gauche de l'écran)
  def bord_gauche(vp)
    return vp && vp.instance_variable_get(:@ecran_gauche) ? 0 : logique_gauche
  end

  # @param vp [Viewport, nil]
  # @return [Boolean] vrai si le viewport est un viewport de cadre
  def cadre?(vp)
    return !vp.nil? && vp.instance_variable_defined?(:@ecran_reel)
  end

  # Exécute le bloc sans redirection des viewports (pour créer de vrais viewports plein écran)
  def contourner
    ancien = @contourner
    @contourner = true
    yield
  ensure
    @contourner = ancien
  end

  # @return [Boolean]
  def contourner?
    return @contourner == true
  end

  # Scène en cours de construction (ses viewports sont parfois créés dans initialize, avant que $scene ne la désigne)
  # @return [Object, nil]
  def scene_construite
    return @scene_construite
  end

  # Exécute le bloc en déclarant la scène en construction
  # @param scene [Object]
  def construire(scene)
    ancienne = @scene_construite
    @scene_construite = scene
    yield
  ensure
    @scene_construite = ancienne
  end

  # Scène à laquelle appartient un viewport créé maintenant
  # @return [Object, nil]
  def scene_active
    return @scene_construite || $scene
  end

  # Viewport plein écran (coordonnées réelles), jamais transformé
  # @param z [Integer]
  # @return [Viewport]
  def viewport_plein(z)
    return contourner { Viewport.create(0, 0, largeur, hauteur, z) }
  end

  # Fait voir au viewport un écran logique (lx, ly, lw, lh) : zoom + rect logique pour les lecteurs (rect.width...)
  # @param vp [Viewport] viewport créé avec le rect réel
  # @return [Viewport]
  # @param gauche [Boolean] le point (0, 0) de l'interface est le coin haut gauche de TOUT l'écran (et non du cadre 320x240)
  # @param placement [Array(Integer, Integer), nil] décalage réel (x, y) d'un viewport numérique ; ses changements de rect (animations
  #   de hauteur…) sont répercutés sur le vrai rect
  def adapter(vp, lx, ly, lw, lh, gauche: false, placement: nil)
    return vp if vp.instance_variable_defined?(:@ecran_reel)

    decal = gauche ? -logique_gauche : 0
    vp.instance_variable_set(:@ecran_gauche, gauche)

    reel = vp.rect
    logique = RectLogique.new(vp, reel, lx, ly, lw, lh, placement)
    vp.instance_variable_set(:@ecran_reel, reel)
    vp.define_singleton_method(:rect) { logique }
    # Souris : les coordonnées de la souris sont celles de l'écran ; on les convertit vers l'interface 320x240 logique
    vp.define_singleton_method(:simple_mouse_in?) do |mouse_x = Mouse.x, mouse_y = Mouse.y|
      r = @ecran_reel
      r.x <= mouse_x && mouse_x < r.x + r.width && r.y <= mouse_y && mouse_y < r.y + r.height
    end
    vp.define_singleton_method(:translate_mouse_coords) do |mouse_x = Mouse.x, mouse_y = Mouse.y|
      r = @ecran_reel
      e = Ecran.echelle
      depart_x = r.x + (r.width - rect.width * e) / 2.0
      depart_y = r.y + (r.height - rect.height * e) / 2.0
      [((mouse_x - depart_x) / e).floor + ox + decal, ((mouse_y - depart_y) / e).floor + oy]
    end
    # Le zoom d'un viewport se fait autour de son centre : on compense par une origine de base pour que le point (0, 0)
    # de l'interface reste dans le coin de son cadre (centré dans le viewport). ox / oy restent ceux de la scène.
    vp.zoom = echelle if echelle != 1
    set_ox = vp.method(:ox=)
    set_oy = vp.method(:oy=)
    vp.instance_variable_set(:@ecran_ox, 0)
    vp.instance_variable_set(:@ecran_oy, 0)
    vp.define_singleton_method(:ox) { @ecran_ox }
    vp.define_singleton_method(:oy) { @ecran_oy }
    vp.define_singleton_method(:ox=) { |v| @ecran_ox = v; set_ox.call(v + decal + Ecran.base_origine(logique.width, @ecran_reel.width)) }
    vp.define_singleton_method(:oy=) { |v| @ecran_oy = v; set_oy.call(v + Ecran.base_origine(logique.height, @ecran_reel.height)) }
    vp.ox = 0
    vp.oy = 0
    return vp
  end

  # Rect vu par les scènes (coordonnées logiques 320x240). Si le viewport est numérique, toute modification est
  # répercutée (mise à l'échelle) sur le vrai rect du viewport : animations de hauteur (journal de quêtes…)
  class RectLogique
    attr_reader :x, :y, :width, :height

    def initialize(vp, reel, x, y, width, height, placement)
      @vp = vp
      @reel = reel
      @placement = placement
      @x = x
      @y = y
      @width = width
      @height = height
    end

    def x=(value)
      @x = value
      synchroniser
    end

    def y=(value)
      @y = value
      synchroniser
    end

    def width=(value)
      @width = value
      synchroniser
    end

    def height=(value)
      @height = value
      synchroniser
    end

    # @return [Array<Integer>]
    def to_a
      return [@x, @y, @width, @height]
    end

    def to_s
      return "(#{@x}, #{@y}, #{@width}, #{@height})"
    end

    def ==(other)
      return other.respond_to?(:to_a) && to_a == other.to_a
    end

    def set(x, y, width, height)
      @x = x
      @y = y
      @width = width
      @height = height
      synchroniser
      return self
    end

    private

    def synchroniser
      return unless @placement

      e = Ecran.echelle
      @reel.set(@placement[0] + (@x * e).round, @placement[1] + (@y * e).round, [(@width * e).round, 0].max, [(@height * e).round, 0].max)
      @vp.ox = @vp.ox
      @vp.oy = @vp.oy
    end
  end

  # Origine de base : centre l'interface logique (taille logique) dans le viewport réel (taille réelle) malgré le zoom
  # @param logique [Numeric] taille logique de l'interface
  # @param reel [Numeric] taille réelle du viewport
  # @return [Integer]
  def base_origine(logique, reel)
    return ((logique - reel) / 2.0).round
  end

  # Place un viewport cadré aux coordonnées de l'ancien écran 320×240 (équivalent de rect.set(x, y, w, h))
  # @param vp [Viewport]
  def placer(vp, x, y, w, h)
    reel = vp.instance_variable_get(:@ecran_reel)
    if reel
      e = echelle
      reel.set(decalage_x + (x * e).round, decalage_y + (y * e).round, (w * e).round, (h * e).round)
    end
    vp.rect.set(x, y, w, h)
    if reel
      vp.ox = vp.ox
      vp.oy = vp.oy
    end
    return vp
  end

  # @param z [Integer]
  # @param fond [Boolean] fond noir derrière le cadre
  # @return [Viewport]
  def viewport(z, fond: false)
    configurer
    # Le fond noir est créé AVANT le cadre : à z différent le tri les range bien, et à défaut l'ordre de création reste correct
    fond_objets = fond && grand? ? creer_fond(z) : nil
    vp = Viewport.create(:frame, z)
    lier_fond(vp, fond_objets) if fond_objets
    Graphics.sort_z if Graphics.respond_to?(:sort_z)
    return vp
  end

  # Fond noir plein écran (viewport + sprite)
  # @param z [Integer] z du cadre ; le fond est juste derrière
  # @return [Array(Viewport, Sprite), nil]
  def creer_fond(z)
    fond_vp = viewport_plein(z - 1)
    sprite = Sprite.new(fond_vp)
    sprite.bitmap = Bitmap.new(largeur, hauteur)
    sprite.bitmap.fill_rect(0, 0, largeur, hauteur, Color.new(0, 0, 0))
    return [fond_vp, sprite]
  rescue StandardError
    return nil
  end

  # Le fond est supprimé en même temps que le viewport donné
  # @param vp [Viewport]
  # @param objets [Array(Viewport, Sprite)]
  def lier_fond(vp, objets)
    fond_vp, sprite = objets
    original = vp.method(:dispose)
    vp.define_singleton_method(:dispose) do
      sprite.dispose unless sprite.disposed?
      fond_vp.dispose unless fond_vp.disposed?
      original.call
    end
  end

  # Fond noir plein écran, supprimé en même temps que le viewport donné
  # @param vp [Viewport]
  # @param z [Integer]
  def attacher_fond(vp, z)
    objets = creer_fond(z)
    lier_fond(vp, objets) if objets
  end

  # Seule la carte garde l'écran entier (les autres scènes peuvent répondre true à plein_ecran?)
  # @param scene [Object]
  # @return [Boolean]
  def plein_ecran?(scene)
    return true if scene.respond_to?(:plein_ecran?) && scene.plein_ecran?
    return true if defined?(::Scene_Map) && scene.is_a?(::Scene_Map)

    return false
  end

  # Redirige et adapte les viewports créés pendant une scène encadrée (la scène en cours est $scene)
  module CadreViewport
    def create(*args, **kwargs)
      logique = nil
      placement = nil
      if Ecran.grand? && !Ecran.contourner?
        scene = Ecran.scene_active
        framed = scene && !Ecran.plein_ecran?(scene)
        if args[0] == :frame || (args[0] == :main && framed)
          Ecran.configurer
          args[0] = :frame
          logique = [0, 0, Ecran::BASE_LARGEUR, Ecran::BASE_HAUTEUR]
        elsif framed && args[0].is_a?(Integer) && args[1].is_a?(Integer) && args.size >= 4
          # Viewport.create(x, y, w, h, z) pensé pour 320x240
          e = Ecran.echelle
          logique = args[0, 4]
          dx = scene.respond_to?(:origine_gauche?) && scene.origine_gauche? ? 0 : Ecran.decalage_x
          placement = [dx, Ecran.decalage_y]
          args = [dx + (args[0] * e).round, Ecran.decalage_y + (args[1] * e).round,
                  (args[2] * e).round, (args[3] * e).round, *args[4..-1]]
        end
      end
      vp = kwargs.empty? ? super(*args) : super(*args, **kwargs)
      if logique
        scene = Ecran.scene_active
        plein_cadre = logique[2] == Ecran::BASE_LARGEUR && logique[3] == Ecran::BASE_HAUTEUR && args[0] == :frame
        gauche = plein_cadre && scene.respond_to?(:origine_gauche?) && scene.origine_gauche? ? true : false
        Ecran.adapter(vp, *logique, gauche: gauche, placement: placement)
      end
      return vp
    end
  end

  # Le fond flou (capture de l'écran précédent) doit couvrir toute la fenêtre, pas seulement le cadre
  module BlurPleinEcran
    def initialize(viewport = nil, last_scene)
      if Ecran.grand? && viewport && viewport.instance_variable_defined?(:@ecran_reel)
        @ecran_vp = Ecran.viewport_plein(viewport.z - 1)
        viewport = @ecran_vp
      end
      super(viewport, last_scene)
    end

    def dispose
      super
      @ecran_vp.dispose if @ecran_vp && !@ecran_vp.disposed?
      @ecran_vp = nil
    end
  end

  # La capture de la carte doit se faire en plein écran même depuis un menu encadré
  module CapturePleinEcran
    def snap_to_bitmap
      return Ecran.contourner { super }
    end
  end

  # Déclare la scène en construction pendant tout son initialize (GamePlay::Base.new)
  module ConstructionScene
    def new(*args, **kwargs, &block)
      objet = allocate
      Ecran.construire(objet) do
        kwargs.empty? ? objet.send(:initialize, *args, &block) : objet.send(:initialize, *args, **kwargs, &block)
      end
      return objet
    end
  end

  # Ajoute le cadrage aux scènes GamePlay::Base
  module CadreScene
    # @param no_message [Boolean]
    # @param message_z [Integer]
    # @param message_viewport_args [Array]
    def initialize(no_message = false, message_z = 20_000, *message_viewport_args)
      if message_viewport_args.empty? && Ecran.grand? && !Ecran.plein_ecran?(self)
        Ecran.configurer
        message_viewport_args = [:frame, message_z]
      end
      super(no_message, message_z, *message_viewport_args)
    end

    private

    def create_viewport
      return super if !Ecran.grand? || Ecran.plein_ecran?(self)

      @viewport = Ecran.viewport(10_000, fond: true)
    end
  end
end

Ecran.configurer rescue nil
GamePlay::Base.prepend(Ecran::CadreScene) if defined?(GamePlay::Base)
GamePlay::Base.singleton_class.prepend(Ecran::ConstructionScene) if defined?(GamePlay::Base) && !GamePlay::Base.singleton_class.include?(Ecran::ConstructionScene)
Viewport.singleton_class.prepend(Ecran::CadreViewport) if defined?(Viewport) && !Viewport.singleton_class.include?(Ecran::CadreViewport)
UI::BlurScreenshot.prepend(Ecran::BlurPleinEcran) if defined?(UI::BlurScreenshot) && !UI::BlurScreenshot.include?(Ecran::BlurPleinEcran)
Scene_Map.prepend(Ecran::CapturePleinEcran) if defined?(Scene_Map) && !Scene_Map.include?(Ecran::CapturePleinEcran)

# Diagnostic : écrit dans Ecran_diagnostic.log l'état des viewports de chaque scène ouverte (aide à trouver un écran noir)
module Ecran
  module Diagnostic
    private

    def main_begin
      super
      begin
        lignes = ["#{Time.now} #{self.class} plein_ecran=#{Ecran.plein_ecran?(self)} gauche=#{respond_to?(:origine_gauche?) && origine_gauche?}"]
        ObjectSpace.each_object(Viewport) do |vp|
          next if vp.disposed?

          reel = vp.instance_variable_get(:@ecran_reel) || vp.rect
          lignes << "  vp z=#{vp.z} idx=#{vp.__index__ rescue '?'} visible=#{vp.visible} reel=#{reel.x},#{reel.y},#{reel.width},#{reel.height} zoom=#{vp.zoom_x rescue '?'} ox=#{vp.ox} oy=#{vp.oy}"
        end
        File.open('Ecran_diagnostic.log', 'a') { |f| f.puts(lignes) }
      rescue StandardError
        nil
      end
    end
  end
end
module Ecran
  module DiagnosticSprites
    def update(*args, &block)
      resultat = super
      @ecran_diag_frames = (@ecran_diag_frames || 0) + 1
      Ecran.diagnostic_sprites(self) if @ecran_diag_frames == 30
      return resultat
    end
  end

  # Écrit l'état des sprites du viewport de la scène (nom, position, zoom, visibilité, bitmap)
  def self.diagnostic_sprites(scene)
    vp = scene.instance_variable_get(:@viewport)
    return unless vp

    lignes = ["#{Time.now} SPRITES #{scene.class} viewport z=#{vp.z} visible=#{vp.visible} rect=#{vp.rect.to_a.inspect}"]
    n = 0
    ObjectSpace.each_object(Sprite) do |sp|
      next if sp.disposed? || sp.viewport != vp

      n += 1
      next if n > 80

      bmp = sp.bitmap
      taille = bmp && !bmp.disposed? ? "#{bmp.width}x#{bmp.height}" : 'nil'
      lignes << "  x=#{sp.x} y=#{sp.y} z=#{sp.z} vis=#{sp.visible} op=#{sp.opacity} zx=#{sp.zoom_x} bmp=#{taille}"
    end
    lignes << "  total=#{n}"
    File.open('Ecran_diagnostic.log', 'a') { |f| f.puts(lignes) }
  rescue StandardError => e
    File.open('Ecran_diagnostic.log', 'a') { |f| f.puts("diagnostic_sprites: #{e.class} #{e.message}") } rescue nil
  end
end
GamePlay::Base.prepend(Ecran::Diagnostic) if defined?(GamePlay::Base)
GamePlay::Base.prepend(Ecran::DiagnosticSprites) if defined?(GamePlay::Base)
