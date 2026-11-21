# Insignes : des distinctions pour les Pokémon, comme les rubans (graphics/interface/insignes, catalogue Data/configs/plugins/insignes.json)
#
# Chaque Pokémon garde la liste de ses insignes (sauvegardée avec lui). Un insigne est donné par un évent ou un script :
#   donner_insigne(0, :or_crown_4)        -> le Pokémon n° 0 de l'équipe reçoit l'insigne « or_crown_4 »
# (voir 00101 Commandes.rb). Ils s'affichent dans le résumé du Pokémon, page « Insignes » (plugin interface_pe).
#
# Le catalogue (168 insignes : 6 couleurs x 28) vient de tools/insignes/decouper_planche.py ; on peut modifier à la main
# les noms et descriptions dans Data/configs/plugins/insignes.json, ou en ajouter (image 32x32 dans graphics/interface/insignes/).
module Insignes
  CATALOG_FILE = 'Data/configs/plugins/insignes.json'
  # Dossier des images (dans graphics/interface/)
  DIR = 'insignes/'

  module_function

  # @return [Array<Hash>] tous les insignes : { 'id', 'couleur', 'motif', 'palier', 'nom' => [fr, en], 'description' => [fr, en] }
  def catalog
    return @catalog[:list] if @catalog

    data = File.exist?(CATALOG_FILE) ? JSON.parse(File.read(CATALOG_FILE, encoding: 'UTF-8')) : {}
    list = data['insignes'] || []
    @catalog = { list: list, by_id: list.to_h { |entry| [entry['id'].to_s, entry] } }
    return list
  rescue StandardError => e
    log_error("Insignes : #{CATALOG_FILE} illisible (#{e.message})") if respond_to?(:log_error, true)
    @catalog = { list: [], by_id: {} }
    return []
  end

  # @param id [String, Symbol]
  # @return [Hash, nil]
  def find(id)
    catalog
    return @catalog[:by_id][id.to_s]
  end

  # @param id [String, Symbol]
  # @return [Boolean]
  def exist?(id)
    return !find(id).nil?
  end

  # @param entry [Array<String>] [français, anglais]
  # @return [String]
  def localized(texts)
    texts = Array(texts)
    return ($options&.language == 'fr' ? texts[0] : texts[1] || texts[0]).to_s
  end

  # @param id [String, Symbol]
  # @return [String]
  def name(id)
    entry = find(id)
    return entry ? localized(entry['nom']) : id.to_s
  end

  # @param id [String, Symbol]
  # @return [String]
  def description(id)
    entry = find(id)
    return entry ? localized(entry['description']) : ''
  end

  # @param id [String, Symbol]
  # @return [String] chemin de l'image dans graphics/interface/
  def image(id)
    return "#{DIR}#{id}"
  end

  # --- Insignes d'un Pokémon -----------------------------------------------------------
  # @param pokemon [PFM::Pokemon, nil]
  # @return [Array<String>] ses insignes, dans l'ordre où il les a reçus (ceux qui n'existent plus au catalogue sont ignorés)
  def of(pokemon)
    return [] unless pokemon.respond_to?(:insignes)

    return pokemon.insignes.select { |id| exist?(id) }
  end

  # @return [Boolean] l'insigne a été ajouté (faux : inconnu ou déjà possédé)
  def give(pokemon, id)
    return false unless pokemon.respond_to?(:insignes) && exist?(id) && !has?(pokemon, id)

    pokemon.insignes << id.to_s
    return true
  end

  # @return [Boolean] l'insigne a été retiré
  def remove(pokemon, id)
    return false unless pokemon.respond_to?(:insignes)

    return !pokemon.insignes.delete(id.to_s).nil?
  end

  # @return [Boolean]
  def has?(pokemon, id)
    return pokemon.respond_to?(:insignes) && pokemon.insignes.include?(id.to_s)
  end

  # @param index [Integer] place dans l'équipe (0 = premier Pokémon)
  # @return [PFM::Pokemon, nil]
  def party_member(index)
    party = $actors || ($pokemon_party && $pokemon_party.actors)
    return party && party[index.to_i]
  end

  # Le Pokémon garde ses insignes dans la sauvegarde (variable d'instance du Pokémon)
  module PokemonExtension
    # @return [Array<String>] identifiants de ses insignes
    def insignes
      @pj_insignes ||= []
    end
  end
end

PFM::Pokemon.prepend(Insignes::PokemonExtension) if defined?(PFM::Pokemon)
