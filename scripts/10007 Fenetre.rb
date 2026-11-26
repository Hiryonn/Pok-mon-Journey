# encoding: utf-8
# Fenêtre du jeu : elle tient toujours dans l'écran de l'ordinateur.
#
# Avec la résolution 640×360, l'option « Taille de l'écran » ×3 ou ×4 (gardée d'une ancienne partie, quand le jeu était
# en 320×240) donnait une fenêtre de 1920×1080 ou plus : elle couvrait tout l'écran, comme en plein écran.
#   - au lancement : l'agrandissement est réduit jusqu'à ce que la fenêtre tienne dans l'écran (barre des tâches comprise) ;
#     le jeu démarre en fenêtre, sauf si display_config dit plein écran ou si on le lance avec --fullscreen
#   - dans les options : seules les tailles qui tiennent dans l'écran sont proposées
#   - le viewport « main » (Data/Viewport.json) prend toujours la taille de la résolution
# Réglage du projet (Studio, display_config) : 640×360, agrandissement 2 (fenêtre 1280×720), pas de plein écran.
module Fenetre
  # place laissée autour de la fenêtre (barre des tâches, barre de titre)
  MARGE_LARGEUR = 16
  MARGE_HAUTEUR = 96

  module_function

  # @return [Array(Integer, Integer), nil] taille de l'écran de l'ordinateur
  def bureau
    w = LiteRGSS::DisplayWindow.desktop_width.to_i
    h = LiteRGSS::DisplayWindow.desktop_height.to_i
    return w > 0 && h > 0 ? [w, h] : nil
  rescue StandardError
    return nil
  end

  # @return [Integer] plus grand agrandissement qui tient dans l'écran (au moins 1)
  def agrandissement_max
    taille = bureau
    return 4 unless taille

    w = Configs.display.game_resolution.x
    h = Configs.display.game_resolution.y
    scale = 1
    scale += 1 while (scale + 1) * w <= taille[0] - MARGE_LARGEUR && (scale + 1) * h <= taille[1] - MARGE_HAUTEUR
    return scale
  rescue StandardError
    return 4
  end

  # @param scale [Numeric]
  # @return [Integer]
  def limiter(scale)
    return [[scale.to_i, 1].max, agrandissement_max].min
  end

  # Au lancement (création de la fenêtre)
  module Lancement
    def choose_best_resolution
      plein = PARGV[:fullscreen] == true || Configs.display.is_fullscreen
      result = super
      unless plein || running_editor?
        @running_in_full_screen = false
        @window_scale = Fenetre.limiter(@window_scale)
        @viewport_offset_x = 0
        @viewport_offset_y = 0
        result = [Configs.display.game_resolution.x, Configs.display.game_resolution.y]
      end
      return result
    end
  end

  # Option « Taille de l'écran » pendant le jeu
  module Graphique
    def screen_scale=(scale)
      super(Fenetre.limiter(scale))
    end
  end
end

# Viewport « main » : toujours de la taille de la résolution (un Data/Viewport.rxdata resté en 320×240 après un
# changement de résolution n'affichait la carte que dans le coin haut gauche)
module Fenetre
  module ViewportMain
    def load_configs
      super
      Fenetre.corriger_viewport_main
    end
  end

  def self.corriger_viewport_main
    main = Viewport::CONFIGS[:main]
    w = Configs.display.game_resolution.x
    h = Configs.display.game_resolution.y
    return if main && main[:x].to_i == 0 && main[:y].to_i == 0 && main[:width] == w && main[:height] == h

    Viewport::CONFIGS[:main] = (main || {}).merge(x: 0, y: 0, width: w, height: h)
  rescue StandardError
    nil
  end
end
Viewport.singleton_class.prepend(Fenetre::ViewportMain) if defined?(Viewport) && !Viewport.singleton_class.include?(Fenetre::ViewportMain)
Fenetre.corriger_viewport_main if defined?(Viewport::CONFIGS) && Viewport::CONFIGS[:main]

PSDK_CONFIG.singleton_class.prepend(Fenetre::Lancement) if defined?(PSDK_CONFIG) && !PSDK_CONFIG.singleton_class.include?(Fenetre::Lancement)
Graphics.singleton_class.prepend(Fenetre::Graphique) if defined?(Graphics) && !Graphics.singleton_class.include?(Fenetre::Graphique)

# Options : seules les tailles qui tiennent dans l'écran
if defined?(GamePlay::Options::PREDEFINED_OPTIONS) && GamePlay::Options::PREDEFINED_OPTIONS[:screen_scale]
  module Fenetre
    module Options
      def initialize(*args, **kwargs)
        kwargs.empty? ? super(*args) : super(*args, **kwargs)
        Fenetre.filtrer_options(self)
      end
    end

    # Retire les tailles trop grandes de la liste de l'option (valeurs et textes)
    def self.filtrer_options(scene)
      max = agrandissement_max
      options = scene.instance_variable_get(:@options)
      return unless options.is_a?(Hash) && options[:screen_scale]

      opt = options[:screen_scale]
      values = opt.respond_to?(:values) ? opt.values : nil
      return unless values.is_a?(Array) && values.all? { |v| v.is_a?(Integer) }

      keep = values.each_index.select { |i| values[i] <= max }
      return if keep.size == values.size || keep.empty?

      opt.instance_variable_set(:@values, keep.map { |i| values[i] })
      texts = opt.instance_variable_get(:@values_text)
      opt.instance_variable_set(:@values_text, keep.map { |i| texts[i] }) if texts.is_a?(Array)
    rescue StandardError
      nil
    end
  end
  GamePlay::Options.prepend(Fenetre::Options) unless GamePlay::Options.include?(Fenetre::Options)
end

# Carte : assez de cases dessinées pour la résolution du jeu. Un display_config resté sur les valeurs d'un écran
# 320×240 (tilemap 22×17, liaison des cartes 10×7) ne dessinait le sol que dans un coin de l'écran.
module Fenetre
  def self.corriger_carte
    reglages = Configs.display.tilemap_settings
    tuile = reglages.tilemap_class.to_s.include?('16') ? 16 : 32
    w = Configs.display.game_resolution.x
    h = Configs.display.game_resolution.y
    taille = reglages.tilemap_size
    besoin_x = (w / tuile.to_f).ceil + 2
    besoin_y = (h / tuile.to_f).ceil + 2
    taille.instance_variable_set(:@x, besoin_x) if taille.x < besoin_x
    taille.instance_variable_set(:@y, besoin_y) if taille.y < besoin_y
    return unless defined?(Yuki::MapLinker)

    lien_x = (w / (tuile * 2.0)).ceil
    lien_y = (h / (tuile * 2.0)).ceil
    { OFFSET_X: lien_x, OFFSET_Y: lien_y }.each do |nom, valeur|
      next unless Yuki::MapLinker.const_defined?(nom) && Yuki::MapLinker.const_get(nom) < valeur

      Yuki::MapLinker.send(:remove_const, nom)
      Yuki::MapLinker.const_set(nom, valeur)
    end
  rescue StandardError
    nil
  end
end
Fenetre.corriger_carte
