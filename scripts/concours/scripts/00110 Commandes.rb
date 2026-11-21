# Concours : commandes d'évènement (commande Script)
#   concours                        accueil complet (type, rang, Pokémon) puis le concours ; renvoie la place (0 : abandon)
#   concours(:cool)                 type imposé (cool, beauty, cute, smart, tough) ; concours(:cool, :master) : rang aussi
#   concours_direct(:cute, :great)  sans les messages d'accueil (choix du Pokémon seulement)
#   concours_gagne?                 condition : le dernier concours a été gagné
#   concours_place                  place au dernier concours (0 : jamais joué)
#   concours_victoires(:cool, :normal)  nombre de victoires (sans argument : toutes)
#   mallette                        ouvre la Mallette (accessoires et fonds)
#   mallette_depart                 donne la Mallette de départ réglée dans Studio (une seule fois, sans message)
#   donner_accessoire(:top_hat, 2)  donne un accessoire (avec la musique et le message ; silencieux: true sans)
#   donner_fond(:sky)               donne un fond (silencieux: true sans message)
#   accessoire_nombre(:top_hat)     nombre d'exemplaires dans la Mallette
#   tableau_gagnants                tableau des gagnants de chaque concours
#   dernier_gagnant                 message : dernier gagnant d'un concours
# Objet : Mallette (fashion_case) ouvre la Mallette depuis le sac.
module Concours
  module_function

  def open_scene(klass, *args)
    $scene.call_scene(klass, *args)
  end
end

class Interpreter
  def concours(type = nil, rang = nil)
    return Concours.reception(type&.to_s, rang&.to_s)
  end
  alias contest concours

  def concours_direct(type = nil, rang = nil)
    return Concours.reception(type&.to_s, rang&.to_s, greet: false)
  end

  def concours_gagne?
    last = Concours.last_contest
    return false unless last

    return Concours.record(*last)['last'].to_i == 1
  end

  def concours_place
    last = Concours.last_contest
    return 0 unless last

    return Concours.record(*last)['last'].to_i
  end

  def concours_victoires(type = nil, rang = nil)
    return Concours.record(type.to_s, rang.to_s)['won'].to_i if type && rang

    return Concours.data['stats'].select { |key, _| type.nil? || key.start_with?("#{type}_") }.values.sum { |r| r['won'].to_i }
  end

  def mallette
    Concours.open_scene(Concours::FashionCaseScene)
  end
  alias fashion_case mallette

  def mallette_depart
    return Concours.give_starter
  end

  def donner_accessoire(id, nombre = 1, silencieux: false)
    return Concours.give_accessory(id.to_s, nombre.to_i, !silencieux)
  end

  def donner_fond(id, silencieux: false)
    return Concours.give_backdrop(id.to_s, !silencieux)
  end

  def accessoire_nombre(id)
    return Concours.accessory_count(id.to_s)
  end

  def tableau_gagnants
    Concours.open_scene(Concours::WinnersScene)
  end

  def dernier_gagnant
    record = Concours.last_winner
    unless record
      $scene.display_message(Concours.t('Personne n’a gagné de concours récemment...', 'Nobody has won a contest recently...'))
      return
    end
    species = data_creature(record['species'].to_sym).name rescue record['species']
    name = Concours.contest_name(record['type'], record['rank'])
    $scene.display_message(Concours.t("Dernier gagnant (#{name}) : #{record['trainer']} et #{record['name']} (#{species}) !",
                                      "Most recent winner (#{name}): #{record['trainer']} with #{record['name']} the #{species}!"))
  end
end

# Objet : la Mallette s'ouvre depuis le sac (elle n'est pas consommée)
PFM::ItemDescriptor.define_bag_use(:fashion_case, true) do |_item, scene|
  scene.call_scene(Concours::FashionCaseScene)
  next :unused
end
