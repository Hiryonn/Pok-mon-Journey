# Pokéathlon : commandes d'évènement (Script)
#
#   pokeathlon                    -> ouvre le Pokéathlon (choix de la coupe)
#   pokeathlon('speed')           -> coupe imposée (speed, power, skill, stamina, jump ou coupe réglée dans Studio)
#   pokeathlon_resultat           -> résultat de la dernière coupe : { course:, rank: (1 à 4), points: } ou nil (abandon)
#   pokeathlon_gagne?             -> true si la dernière coupe a été gagnée
#   mixeur_noigrumes              -> ouvre le Mixeur à Noigrumes (si l'objet blender_item est dans le sac, sauf réglage vide)
#   donnees_pokeathlon            -> écran des Données du Pokéathlon (records, médailles, coupes gagnées)
#   boutique_pokeathlon           -> boutique du jour (points Pokéathlon) ; plugin magasins nécessaire
#   points_pokeathlon             -> points Pokéathlon du joueur
#   ajouter_points_pokeathlon(n)  -> ajoute (ou retire si négatif) des points
#   pokeathlon_gagnees('speed')   -> nombre de victoires dans une coupe
#   pokeathlon_jus_pret?          -> true si un jus est prêt dans le mixeur
class Interpreter
  def pokeathlon(course = nil)
    @pj_athlon_result = nil
    $scene.call_scene(GamePlay::PokeathlonScene, course&.to_s) { |scene| @pj_athlon_result = scene.result }
    @wait_count = 2
    return @pj_athlon_result
  end

  def pokeathlon_resultat
    return @pj_athlon_result
  end

  def pokeathlon_gagne?
    return @pj_athlon_result ? @pj_athlon_result[:rank] == 1 : false
  end

  def mixeur_noigrumes
    item = Pokeathlon.setting('blender_item').to_s
    unless item.empty? || $bag.contain_item?(item.to_sym)
      message(Pokeathlon.t('Il te faut une Boîte Noigrumes.', 'You need an Apricorn Box.'))
      return false
    end
    $scene.call_scene(GamePlay::PokeathlonBlender)
    @wait_count = 2
    return true
  end

  def donnees_pokeathlon
    $scene.call_scene(GamePlay::PokeathlonData)
    @wait_count = 2
    return true
  end

  def boutique_pokeathlon
    unless defined?(Magasins) && respond_to?(:magasin)
      log_error('Pokéathlon : plugin magasins absent') if respond_to?(:log_error, true)
      return false
    end

    return magasin('pokeathlon')
  end

  def points_pokeathlon
    return Pokeathlon.points
  end

  def ajouter_points_pokeathlon(amount)
    Pokeathlon.add_points(amount)
    return Pokeathlon.points
  end

  def pokeathlon_gagnees(course)
    return Pokeathlon.data['wins'][course.to_s].to_i
  end

  def pokeathlon_jus_pret?
    return Pokeathlon.blender_state == :ready
  end
end
