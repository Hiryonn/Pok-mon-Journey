# Pokéblocs : commandes d'évènement (commande Script)
#   mixeur_baies                 mixeur à jouer, seul (renvoie le nombre de Pokéblocs obtenus)
#   mixeur_baies(3)              avec 1 à 3 autres joueurs (noms au hasard, ou noms: ['Léa', 'Tom', 'Max'])
#   mixeur_maitre                avec le Maître Baies (nom au hasard, ou mixeur_maitre('Diane'))
#   mixeur_simple                mixeur du Kit Pokébloc (1 à 4 baies, sans mini-jeu)
#   mixeur                       celui du mode réglé dans Studio (rse : mixeur à jouer, oras : mixeur simple)
#   boite_pokeblocs              ouvre la Boîte Pokébloc
#   etat_pokemon                 conditions de concours des Pokémon de l'équipe
#   donner_pokebloc(:red, 2, plus: true)   donne des Pokéblocs (red, blue, pink, green, yellow, rainbow, gold…)
#   pokeblocs_nombre             nombre de Pokéblocs dans la Boîte (pokeblocs_nombre(:red) : d'une couleur)
# Objets : Boîte Pokébloc (pokeblock_case) ouvre la Boîte, Kit Pokébloc (pokeblock_kit) ouvre le mixeur simple.
module Pokeblocs
  module_function

  def open_scene(klass, *args)
    bgm = $game_system.playing_bgm
    result = nil
    $scene.call_scene(klass, *args) { |scene| result = scene }
    $game_system.bgm_play(bgm) if bgm && !Pokeblocs.setting('bgm').to_s.empty?
    return result
  end

  # @return [Integer] Pokéblocs obtenus
  def blender(players = 0, names = nil, fail = false)
    return 0 unless ready_to_blend?

    return open_scene(BlenderScene, players, names, fail)&.made.to_i
  end

  def simple_blender
    return 0 unless ready_to_blend?

    return open_scene(SimpleBlenderScene)&.made.to_i
  end

  def ready_to_blend?
    if bag_berries.empty?
      $scene.display_message(t('Vous n’avez pas de baies !', "You don't have any Berries!"))
      return false
    end
    if full?
      $scene.display_message(t('La Boîte Pokébloc est pleine !', 'The Pokéblock Case is full!'))
      return false
    end
    return true
  end

  def open_case
    return open_scene(CaseScene)
  end
end

class Interpreter
  def mixeur_baies(joueurs = 0, noms: nil, rate: false)
    return Pokeblocs.blender(joueurs.to_i.clamp(0, 3), noms, rate)
  end
  alias berry_blender mixeur_baies

  def mixeur_maitre(nom = nil)
    return Pokeblocs.blender(4, nom ? [nom] : nil)
  end

  def mixeur_simple
    return Pokeblocs.simple_blender
  end

  def mixeur(joueurs = 0)
    return Pokeblocs.simple? ? Pokeblocs.simple_blender : Pokeblocs.blender(joueurs.to_i.clamp(0, 3))
  end

  def boite_pokeblocs
    Pokeblocs.open_case
    return Pokeblocs.blocks.size
  end
  alias pokeblock_case boite_pokeblocs

  def etat_pokemon
    Pokeblocs.open_scene(Pokeblocs::ConditionScene, nil)
  end

  # @param couleur [Symbol, String] red, blue, pink, green, yellow, purple, indigo, brown, liteblue, olive, gold,
  #   gray, white, black, rainbow
  # @return [Integer] nombre de Pokéblocs rangés
  def donner_pokebloc(couleur = :red, nombre = 1, plus: false, niveau: nil, douceur: nil)
    color = couleur.to_s.downcase.delete(' _')
    value = (niveau || (plus ? 15 : 5)).to_i
    values = case color
             when 'rainbow' then [value] * 5
             when *Pokeblocs::SINGLE then [0, 0, 0, 0, 0].tap { |v| v[Pokeblocs::SINGLE.index(color)] = value }
             when *Pokeblocs::DOUBLE then [0, 0, 0, 0, 0].tap { |v| i = Pokeblocs::DOUBLE.index(color); v[i] = value; v[(i + 2) % 5] = value / 2 }
             else [value, value / 2, value / 2, 0, 0]
             end
    given = 0
    nombre.to_i.times do
      break unless Pokeblocs.add(Pokeblocs.make(color, values, (douceur || (color == 'rainbow' ? 40 : 15)).to_i, plus))

      given += 1
    end
    return given
  end
  alias give_pokeblock donner_pokebloc

  def pokeblocs_nombre(couleur = nil)
    return Pokeblocs.blocks.size unless couleur

    color = couleur.to_s.downcase.delete(' _')
    return Pokeblocs.blocks.count { |block| block['color'] == color }
  end
end

# Objets : la Boîte et le Kit s'utilisent depuis le sac (ils ne sont pas consommés)
PFM::ItemDescriptor.define_bag_use(:pokeblock_case, true) do |_item, scene|
  scene.call_scene(Pokeblocs::CaseScene)
  next :unused
end

PFM::ItemDescriptor.define_bag_use(:pokeblock_kit, true) do |_item, scene|
  if Pokeblocs.bag_berries.empty?
    scene.display_message(Pokeblocs.t('Vous n’avez pas de baies !', "You don't have any Berries!"))
  elsif Pokeblocs.full?
    scene.display_message(Pokeblocs.t('La Boîte Pokébloc est pleine !', 'The Pokéblock Case is full!'))
  else
    scene.call_scene(Pokeblocs.simple? ? Pokeblocs::SimpleBlenderScene : Pokeblocs::BlenderScene)
  end
  next :unused
end
