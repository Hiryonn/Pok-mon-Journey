# Pokémon Obscurs : commandes d'évènement (commande Script)
#   pokemon_obscur(:species, 30, id: 'x', gauge: 4000, moves: [:shadow_rush])  crée un Pokémon Obscur (sans le donner)
#   ajouter_pokemon_obscur(:species, 30, ...)   donne un Pokémon Obscur au joueur (équipe ou PC)
#   combat_obscur(:species, 30, ...)            combat contre un Pokémon Obscur sauvage (capturable avec une Ball)
#   pierre_relique                              Pierre Relique : choisir un Pokémon dont la jauge est vide et le purifier
#   chambre_purification                        ouvre la Chambre de purification
#   obscur?(0)                                  le Pokémon n° 1 de l'équipe est Obscur
#   jauge_coeur(0)                              barres de la jauge du Pokémon n° 1 (0 à 5)
#   statut_obscur('id')                         'seen', 'missed', 'snagged', 'purified' ou nil
#   obscurs_purifies                            nombre de Pokémon Obscurs purifiés
#   obscurs_captures                            nombre de Pokémon Obscurs capturés (ou purifiés)
class Interpreter
  def pokemon_obscur(species, level = 30, id: nil, gauge: nil, moves: nil, shiny: false, form: 0)
    return Obscurs.create(species, level, id: id, gauge: gauge, moves: moves, shiny: shiny, form: form)
  end
  alias shadow_pokemon pokemon_obscur

  def ajouter_pokemon_obscur(species, level = 30, **opts)
    pokemon = pokemon_obscur(species, level, **opts)
    Obscurs.record(pokemon, 'snagged')
    add_pokemon(pokemon)
    return pokemon
  end
  alias add_shadow_pokemon ajouter_pokemon_obscur

  def combat_obscur(species, level = 30, **opts)
    pokemon = pokemon_obscur(species, level, **opts)
    call_battle_wild(pokemon, nil)
    return pokemon
  end
  alias shadow_battle combat_obscur

  def pierre_relique
    if $actors.none?(&:shadow?)
      message(Obscurs.t('Aucun Pokémon de l’équipe n’est un Pokémon Obscur.', 'None of your Pokémon is a Shadow Pokémon.'))
      return false
    end
    message(Obscurs.t('La Pierre Relique peut purifier un Pokémon Obscur au cœur grand ouvert.',
                      'The Relic Stone can purify a Shadow Pokémon whose heart is fully open.'))
    index = -1
    GamePlay.open_party_menu_to_select_pokemon($actors) { |menu| index = menu.return_data }
    pokemon = index.to_i >= 0 ? $actors[index] : nil
    return false unless pokemon

    unless pokemon.shadow?
      message(Obscurs.t("#{pokemon.given_name} n’est pas un Pokémon Obscur.", "#{pokemon.given_name} isn't a Shadow Pokémon."))
      return false
    end
    unless pokemon.purifiable?
      message(Obscurs.t("Le cœur de #{pokemon.given_name} n’est pas encore assez ouvert...", "#{pokemon.given_name}'s heart isn't open enough yet..."))
      return false
    end
    return Obscurs.purify(pokemon)
  end
  alias relic_stone pierre_relique

  def chambre_purification
    Obscurs.open_chamber
  end
  alias purify_chamber chambre_purification

  def obscur?(index = 0)
    return $actors[index]&.shadow? ? true : false
  end

  def jauge_coeur(index = 0)
    return $actors[index]&.heart_stage.to_i
  end

  def statut_obscur(id)
    return Obscurs.status(id)
  end

  def obscurs_purifies
    return Obscurs.data['seen'].count { |_, entry| entry['status'] == 'purified' }
  end

  def obscurs_captures
    return Obscurs.data['seen'].count { |_, entry| %w[snagged purified].include?(entry['status']) }
  end
end
