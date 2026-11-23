# Pokémon Obscurs : design propre aux Pokémon Obscurs (Mewtwo Obscur, ses Méga-évolutions…)
#
# Un Pokémon Obscur peut avoir ses propres images (face, dos, icône) ; quand il est purifié, il retrouve les normales.
# Deux façons de les donner, la première gagne :
#   1. Studio, Données > Gimmicks > Pokémon Obscurs > onglet Designs (réglage « designs ») : espèce, forme (-1 : toutes
#      les formes) et nom des images pour la face, le dos et l'icône. Une image laissée vide suit la règle 2.
#   2. Automatique : une image nommée comme le sprite normal suivi de « _shadow » (au même endroit que lui) est utilisée.
#        graphics/pokedex/pokefront/0150_shadow.png     face de Mewtwo Obscur
#        graphics/pokedex/pokeback/0150_shadow.png      dos
#        graphics/pokedex/pokeicon/0150_shadow.png      icône
#        graphics/pokedex/pokefront/0150_1_shadow.png   face de la forme 1 (Méga-Mewtwo X, selon la numérotation des formes)
#      (le nom du sprite normal est celui de Studio : pokefront/<nom>.png)
# Sans image Obscure, le Pokémon garde son sprite normal. Un chromatique Obscur utilise le même design.
# Les sprites animés (.gif) ne sont pas utilisés quand un design existe : l'image fixe est affichée.
module Obscurs
  DESIGN_SUFFIX = '_shadow'
  DESIGN_DIRS = { front: 'graphics/pokedex/pokefront', back: 'graphics/pokedex/pokeback' }.freeze

  module_function

  # @return [Array<Hash>] designs de Studio
  def design_entries
    return Array(config.designs).select { |entry| entry.is_a?(Hash) }
  end

  # @param pokemon [PFM::Pokemon]
  # @param kind [Symbol] :front, :back ou :icon
  # @return [String, nil] nom de l'image du design Obscur (nil : aucun, sprite normal)
  def design_name(pokemon, kind)
    return nil unless pokemon.respond_to?(:shadow?) && pokemon.shadow?
    return nil if pokemon.egg?

    key = [pokemon.id, pokemon.form, pokemon.db_symbol, kind]
    @design_cache ||= {}
    return @design_cache[key] if @design_cache.key?(key)

    return @design_cache[key] = find_design(pokemon, kind)
  rescue StandardError
    return nil
  end

  def find_design(pokemon, kind)
    entry = design_entries.find { |e| design_match?(e, pokemon) }
    wanted = entry && fetch(entry, kind).to_s.strip
    return wanted if wanted && !wanted.empty? && design_file?(kind, wanted)

    base = PFM::Pokemon.send("#{kind}_filename", pokemon.id, pokemon.form, pokemon.female?, false, false).to_s
    return nil if base.empty? || base == '000'

    name = "#{base}#{DESIGN_SUFFIX}"
    return design_file?(kind, name) ? name : nil
  end

  def design_match?(entry, pokemon)
    species = fetch(entry, 'species').to_s
    return false unless species == pokemon.db_symbol.to_s

    form = fetch(entry, 'form')
    return form.nil? || form.to_i < 0 || form.to_i == pokemon.form
  end

  def design_file?(kind, name)
    return RPG::Cache.b_icon_exist?(name) if kind == :icon

    return File.exist?("#{DESIGN_DIRS[kind]}/#{name}.png")
  end

  # Après un changement des réglages
  def reload_designs
    @design_cache = nil
  end
end

module Obscurs
  # Ajouts à PFM::Pokemon : sprites des Pokémon Obscurs
  module PokemonDesign
    def icon
      name = Obscurs.design_name(self, :icon)
      return name ? RPG::Cache.b_icon(name) : super
    end

    def battler_face
      name = Obscurs.design_name(self, :front)
      return name ? RPG::Cache.poke_front(name, 0) : super
    end
    alias battler_front battler_face

    def battler_back
      name = Obscurs.design_name(self, :back)
      return name ? RPG::Cache.poke_back(name, 0) : super
    end

    def gif_face
      return Obscurs.design_name(self, :front) ? nil : super
    end

    def gif_back
      return Obscurs.design_name(self, :back) ? nil : super
    end
  end
end

PFM::Pokemon.prepend(Obscurs::PokemonDesign)
