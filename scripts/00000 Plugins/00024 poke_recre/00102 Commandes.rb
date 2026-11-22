# Poké Récré : commandes, appli du téléphone et Pokémon qui suit le joueur
#
# Commandes d'évènement (Script) :
#   poke_recre                  -> ouvre Poké Récré avec le premier Pokémon de l'équipe (pas un œuf)
#   poke_recre(2)               -> avec le Pokémon n° 2 de l'équipe
#   affection_pokemon(0)        -> niveau d'affection (0 à 5 cœurs) du Pokémon n° 0 ; affection_pokemon(0, true) : points
#   donner_affection(0, 50)     -> ajoute (ou retire) des points d'affection (0 à 255)
#   satiete_pokemon(0) / bonne_humeur_pokemon(0) -> niveaux (0 à 5)
#   donner_pofiterole('sucree_creme', 2)  -> donne des Pofiteroles (ids : <saveur>_<niveau>, saveurs sucree, mentholee,
#                               aigre, amere, epicee ; niveaux simple, creme, decoree, deluxe ; ou celebration,
#                               anniversaire, printemps, ete, automne, hiver) ; donner_pofiterole(nil, 3) : au hasard
#   pofiteroles('sucree_creme') -> nombre qu'on a (pofiteroles : toutes)
#   donner_decoration('coeur_fire') -> débloque une décoration (nil : une au hasard) ; decoration_debloquee?(id)
#   changer_fond_poke_recre('type_fire') -> impose le fond ('auto' : selon l'endroit)
#   cueille_baies(0) / jongle_tete(0)    -> lance un mini-jeu avec le Pokémon n° 0 ; renvoie les points (nil : quitté)
#   record_poke_recre('cueille')         -> meilleur score ('cueille' ou 'jongle')
# Téléphone : appli « Poké Récré » (action open_amie). Pokémon qui suit : réglage follower (ask, direct, off).
class Interpreter
  # @param index [Integer, nil] place dans l'équipe
  # @return [PFM::Pokemon, nil] Pokémon avec qui on a joué en dernier
  def poke_recre(index = nil)
    PokeRecre.reload if PSDK_CONFIG.debug?
    chosen = nil
    $scene.call_scene(GamePlay::PokeRecre, index && $actors[index]) { |scene| chosen = scene.pokemon }
    @wait_count = 2
    return chosen
  end
  alias pokemon_amie poke_recre
  alias pokemon_refresh poke_recre

  def affection_pokemon(index, points = false)
    pokemon = $actors[index]
    return 0 unless pokemon

    return points ? pokemon.amie_affection : pokemon.affection_level
  end

  def donner_affection(index, points)
    pokemon = $actors[index]
    return false unless pokemon

    pokemon.amie_affection = pokemon.amie_affection + points.to_i
    return true
  end

  def satiete_pokemon(index)
    return $actors[index]&.fullness_level.to_i
  end

  def bonne_humeur_pokemon(index)
    return $actors[index]&.enjoyment_level.to_i
  end

  def donner_pofiterole(id = nil, nombre = 1)
    id ||= PokeRecre.puffs.keys.sample
    return PokeRecre.add_puff(id, nombre)
  end

  def pofiteroles(id = nil)
    return PokeRecre.data['puffs'].values.sum(&:to_i) unless id

    return PokeRecre.puff_count(id)
  end

  def donner_decoration(id = nil)
    id ||= PokeRecre.random_new_decoration
    return id ? PokeRecre.unlock_decoration(id) : false
  end

  def decoration_debloquee?(id)
    return PokeRecre.decoration_owned?(id)
  end

  def changer_fond_poke_recre(name = 'auto')
    PokeRecre.data['backdrop'] = PokeRecre.backdrop_choices.include?(name.to_s) ? name.to_s : 'auto'
  end

  def cueille_baies(index = nil)
    return poke_recre_jeu(GamePlay::PokeRecreBerryPicker, index)
  end

  def jongle_tete(index = nil)
    return poke_recre_jeu(GamePlay::PokeRecreHeadIt, index)
  end

  def record_poke_recre(jeu)
    return PokeRecre.data['records'][jeu.to_s].to_i
  end

  # Mini-jeu lancé par commande : points (nil : quitté), récompenses comme depuis Poké Récré
  def poke_recre_jeu(klass, index)
    PokeRecre.reload if PSDK_CONFIG.debug?
    result = nil
    $scene.call_scene(klass, index && $actors[index]) { |scene| result = scene.result }
    @wait_count = 2
    return nil unless result

    PokeRecre.give_rewards(result[:stars])
    return result[:points]
  end
end

module PokeRecre
  class << self
    # Pokémon qui suit le joueur, à qui on vient de parler : [Pokémon, mode]
    attr_accessor :pending
  end

  module_function

  # Pokémon de l'équipe qui suit le joueur (nil si c'est un humain ou un Pokémon d'un autre)
  def follower_pokemon
    entity = Yuki::FollowMe.send(:follower_entities).first
    return entity.is_a?(PFM::Pokemon) && $actors.include?(entity) && !entity.egg? ? entity : nil
  rescue StandardError
    return nil
  end

  # Sur la carte : on a parlé au Pokémon qui suit
  def talk_to_follower(scene)
    pokemon, mode = pending
    self.pending = nil
    return unless pokemon

    if mode.to_s == 'ask'
      choices = [t('Jouer', 'Play'), t('Parler', 'Talk'), t('Rien', 'Nothing')]
      choice = scene.display_message(t("Que veux-tu faire avec #{pokemon.given_name} ?", "What do you want to do with #{pokemon.given_name}?"), 1, *choices)
      if choice == 1
        $game_temp.common_event_id = Game_CommonEvent::FOLLOWER_SPEECH
        return
      end
      return unless choice == 0
    end
    scene.call_scene(GamePlay::PokeRecre, pokemon)
  end
end

class Game_Player
  # Parler au Pokémon qui suit propose Poké Récré
  module PokeRecreFollower
    private

    def check_follower_trigger_there(new_x, new_y)
      mode = PokeRecre.setting('follower').to_s
      return super if mode == 'off' || !@follower || @follower.is_a?(Game_Event)
      return super unless @follower.x == new_x && @follower.y == new_y

      pokemon = PokeRecre.follower_pokemon
      return super unless pokemon

      @follower.turn_toward_player
      PokeRecre.pending = [pokemon, mode]
      return true
    rescue StandardError => e
      log_error("Poké Récré : #{e.message}") if respond_to?(:log_error, true)
      return super
    end
  end
  prepend PokeRecreFollower
end

class Scene_Map
  module PokeRecreMap
    def update
      super
      return unless PokeRecre.pending && $scene == self && !$game_system.map_interpreter.running?

      PokeRecre.talk_to_follower(self)
    end
  end
  prepend PokeRecreMap
end

# Appli « Poké Récré » du téléphone (PokeSmart : icône icon_amie) ; dans le menu de PSDK, un bouton de plus
module GamePlay
  class Menu
    def open_amie
      call_scene(GamePlay::PokeRecre)
    end

    register_button(:open_amie) { !::PokeRecre.party.empty? } unless ACTION_LIST.include?(:open_amie)
  end
end
