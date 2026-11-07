# Variantes : commandes d'évent (Script)
#   add_pokemon_variant(:pikachu, 10, :gold)   -> donne un Pikachu Doré N.10
#   store_pokemon_variant(:eevee, 5, :radiant) -> l'envoie au PC
#   set_pokemon_variant(0, :silver)            -> 1er Pokémon de l'équipe Argenté (nil = normal)
#   pokemon_variant(0)                         -> :copper, :silver, :gold, :radiant ou nil
#   add_specific_pokemon(id: :pikachu, level: 10, variant: :gold) marche aussi
class Interpreter
  # @param pokemon_id [Integer, Symbol]
  # @param level [Integer]
  # @param variant [Symbol] :copper, :silver, :gold ou :radiant
  # @return [PFM::Pokemon, nil]
  def add_pokemon_variant(pokemon_id, level = 5, variant = :silver)
    return add_pokemon(PFM::Pokemon.new(pokemon_id, level, false, true, -1, variant: variant))
  end
  alias ajouter_pokemon_variante add_pokemon_variant

  # @param pokemon_id [Integer, Symbol]
  # @param level [Integer]
  # @param variant [Symbol]
  # @return [PFM::Pokemon, nil]
  def store_pokemon_variant(pokemon_id, level = 5, variant = :silver)
    return store_pokemon(PFM::Pokemon.new(pokemon_id, level, false, true, -1, variant: variant))
  end

  # @param index [Integer] position dans l'équipe (0 = premier)
  # @param variant [Symbol, nil]
  # @return [Boolean]
  def set_pokemon_variant(index, variant)
    pokemon = $actors[index]
    return false unless pokemon

    pokemon.variant = variant
    return true
  end

  # @param index [Integer]
  # @return [Symbol, nil]
  def pokemon_variant(index)
    return $actors[index]&.variant
  end
end
