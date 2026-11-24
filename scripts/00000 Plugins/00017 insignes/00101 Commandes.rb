# Insignes : commandes d'évent (Script). Le numéro est la place du Pokémon dans l'équipe (0 = le premier).
#
#   donner_insigne(0, :or_crown_4)         -> lui donne l'insigne (vrai si ajouté ; faux s'il l'avait déjà ou s'il n'existe pas)
#   retirer_insigne(0, :or_crown_4)        -> le lui retire
#   insigne?(0, :or_crown_4)               -> condition : il possède cet insigne
#   nombre_insignes(0)                     -> combien il en a
#   donner_tous_les_insignes(0)            -> tous les insignes du catalogue (pour tester)
# Les identifiants sont dans Data/configs/plugins/insignes.json : « <couleur>_<motif>_<palier> », ex. bronze_ball_1, or_crown_4,
# argent_stars_6, rose_wing_heart, bleu_honor. Couleurs : bronze, bleu, rouge, rose, or, argent.
class Interpreter
  # @param index [Integer]
  # @param id [Symbol, String]
  # @return [Boolean]
  def donner_insigne(index, id)
    return Insignes.give(Insignes.party_member(index), id)
  end

  # @return [Boolean]
  def retirer_insigne(index, id)
    return Insignes.remove(Insignes.party_member(index), id)
  end

  # @return [Boolean]
  def insigne?(index, id)
    return Insignes.has?(Insignes.party_member(index), id)
  end

  # @return [Integer]
  def nombre_insignes(index)
    return Insignes.of(Insignes.party_member(index)).size
  end

  # @return [Integer] nombre d'insignes ajoutés
  def donner_tous_les_insignes(index)
    pokemon = Insignes.party_member(index)
    return Insignes.catalog.count { |entry| Insignes.give(pokemon, entry['id']) }
  end
end
