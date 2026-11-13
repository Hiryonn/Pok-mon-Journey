# Personnages : héros du joueur
#
# Commandes d'évent (Script) :
#   choisir_heros                  écran de choix (si plusieurs héros), puis le nom si « Demander le nom » est coché
#   choisir_heros(nom: false)      sans demander le nom
#   changer_heros('hero_2')        prend ce héros (identifiant de Studio ou position : 0 = premier), sans écran
#   changer_heros('hero_2', nom: true) en donnant aussi son nom par défaut au joueur
#   heros_actuel                   identifiant du héros choisi (condition : heros_actuel == 'hero_2')
#   demander_nom_heros             écran du nom du joueur
#   apparence_heros('nage')        le joueur prend l'apparence « nage » (ajoutée dans Studio > Ressources) partout
#   apparence_heros                retour à l'apparence normale (marche, course, vélo… selon ce qu'il fait)
module Personnages
  module_function

  # @return [String, nil]
  def current_hero_id
    return $user_data && $user_data[:pj_hero]
  end

  # @return [Hash, nil]
  def current_hero
    return hero(current_hero_id) || default_hero
  end

  # Donne au joueur l'apparence (et le nom) d'un héros
  # @param data [Hash] héros (réglages de Studio)
  # @param give_name [Boolean] le joueur prend le nom par défaut du héros
  def apply_hero(data, give_name = true)
    return false unless data

    $user_data[:pj_hero] = data['id'].to_s if $user_data
    $game_switches[Yuki::Sw::Gender] = data['gender'].to_s == 'f' if $game_switches
    name = data['name'].to_s
    if give_name && !name.empty?
      $trainer.name = name if $trainer
      $game_actors[1].name = name if $game_actors && $game_actors[1]
    end
    return true if data['generator'] && generator_used?

    actor = $game_actors && $game_actors[1]
    actor.battler_name = data['battler'].to_s if actor
    charset = data['charset'].to_s
    # sprites choisis un par un sans jeu de sprites : base propre au héros (les sprites choisis la remplacent)
    charset = "pj_heros_#{data['id']}" if charset.empty? && !sprites(data).empty?
    $game_player&.set_appearance_set(charset) unless charset.empty?
    return true
  rescue StandardError => e
    log_error("Personnages : héros #{data && data['id']} (#{e.message})") if respond_to?(:log_error, true)
    return false
  end

  # Sprites de la carte choisis un par un dans Studio (Ressources) : { 'walk' => fichier, 'run' => … }
  # @param data [Hash, nil]
  # @return [Hash{String => String}]
  def sprites(data)
    list = data && data['sprites']
    return {} unless list.is_a?(Hash)

    return list.each_with_object({}) { |(k, v), out| out[k.to_s] = v.to_s unless v.to_s.empty? }
  end

  # Fichier à afficher pour un sprite du joueur (« <base>_m_run » -> sprite choisi pour « run »)
  # @param name [String] nom demandé par PSDK
  # @param base [String, nil] base des sprites du joueur
  # @return [String, nil] autre fichier, nil = celui de PSDK
  def sprite_override(name, base)
    return nil if base.nil? || base.empty? || name.nil?

    data = current_hero
    return nil unless data && !data['generator']

    list = sprites(data)
    return nil if list.empty? && !($user_data && $user_data[:pj_hero_look])

    prefix = "#{base}_#{$game_switches[Yuki::Sw::Gender] ? 'f' : 'm'}_"
    return nil unless name.start_with?(prefix)

    # apparence imposée par apparence_heros
    forced = $user_data && $user_data[:pj_hero_look]
    return look_file(data, base, forced) || name if forced

    state = name[prefix.size..]
    return list[state] if list[state]
    # base propre au héros : un état sans sprite prend la marche
    return list['walk'] if base.start_with?('pj_heros_')

    return nil
  end

  # Fichier d'une apparence : choisi dans Studio, sinon <base>_<m|f>_<apparence>
  # @return [String, nil]
  def look_file(data, base, look)
    file = sprites(data)[look.to_s]
    return file if file

    file = "#{base}_#{$game_switches[Yuki::Sw::Gender] ? 'f' : 'm'}_#{look}"
    return RPG::Cache.character_exist?(file) ? file : nil
  end

  # Le générateur de personnages a déjà fait l'apparence du joueur
  # @return [Boolean]
  def generator_used?
    return defined?(::Generateur) && ::Generateur.respond_to?(:spec) && !::Generateur.spec.nil?
  end

  # Nouvelle partie : héros par défaut
  def apply_default_hero
    data = default_hero
    apply_hero(data, true) if data
  end

  # Fichier du personnage de la carte d'un héros (pour l'écran de choix et l'écran du nom)
  # @param data [Hash]
  # @return [String, nil]
  def hero_charset_file(data)
    base = data['charset'].to_s
    return nil if base.empty?

    file = "#{base}_#{data['gender'].to_s == 'f' ? 'f' : 'm'}_walk"
    return RPG::Cache.character_exist?(file) ? file : nil
  end
end

class Game_Player
  module PJPersonnagesSprites
    # Les sprites choisis dans Studio remplacent ceux de la base (marche, course, vélo, surf…)
    def set_appearance(character_name, character_hue = 0)
      other = Personnages.sprite_override(character_name.to_s, @charset_base)
      super(other || character_name, character_hue)
    end
  end
  prepend PJPersonnagesSprites
end

module PFM
  class GameState
    module PJPersonnagesBoot
      private

      # Nouvelle partie : le joueur prend le héros par défaut de Studio
      def rmxp_boot
        super
        Personnages.apply_default_hero
      end
    end
    prepend PJPersonnagesBoot
  end
end

class Interpreter
  # @param nom [Boolean] demande ensuite le nom (si « Demander le nom au joueur » est coché dans Studio)
  # @param annulable [Boolean] B ferme l'écran sans rien changer
  # @return [Boolean] un héros a été choisi
  def choisir_heros(nom: true, annulable: false)
    list = Personnages.heroes
    return false if list.empty?

    chosen = nil
    if list.size == 1
      chosen = list.first
    else
      $scene.call_scene(GamePlay::ChoixHeros, annulable) { |scene| chosen = scene.chosen }
    end
    return false unless chosen

    Personnages.apply_hero(chosen, true)
    demander_nom_heros if nom && Personnages.ask_name?
    personnaliser_joueur(false) if chosen['generator'] && respond_to?(:personnaliser_joueur)
    @wait_count = 2
    return true
  end

  # @param id [String, Symbol, Integer]
  # @param nom [Boolean] donner aussi le nom par défaut du héros
  def changer_heros(id, nom: false)
    data = Personnages.hero(id)
    unless data
      log_error("Personnages : héros #{id.inspect} introuvable")
      return false
    end

    return Personnages.apply_hero(data, nom)
  end

  # @return [String, nil]
  def heros_actuel
    return Personnages.current_hero_id
  end

  # @param look [String, Symbol, nil] apparence ajoutée dans Studio (nil = apparence normale)
  def apparence_heros(look = nil)
    if look.nil? || look.to_s.empty?
      $user_data.delete(:pj_hero_look)
    else
      $user_data[:pj_hero_look] = look.to_s
    end
    $game_player.update_appearance($game_player.pattern) if $game_player.respond_to?(:update_appearance)
    return true
  end

  # Écran du nom du joueur (nom actuel proposé)
  def demander_nom_heros
    hero = Personnages.current_hero
    file = hero && Personnages.hero_charset_file(hero)
    file ||= $game_player.character_name if $game_player && !$game_player.character_name.to_s.empty?
    GamePlay.open_character_name_input($trainer.name, Personnages.name_max_length, file) do |scene|
      name = scene.return_name.to_s
      next if name.empty?

      $trainer.name = name
      $game_actors[1].name = name if $game_actors[1]
    end
  end
end
