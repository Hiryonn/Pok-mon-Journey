# Montures : commandes d'évènement (commande Script)
#   donner_monture('cerfrousse')            débloque une monture (message « … vous rejoint ! », message: false pour aucun)
#   retirer_monture('cerfrousse')           la reprend (le joueur descend s'il était dessus)
#   monture?('cerfrousse')                  condition : monture débloquée
#   monter('cerfrousse')                    monte dessus (sans argument : la dernière monture)
#   descendre                               descend de la monture
#   monte?                                  condition : le joueur est sur une monture
#   monture_actuelle                        identifiant de la monture du joueur (nil à pied)
#   roue_montures                           ouvre la roue des montures
#   appli_monture                           ouvre l'appli Monture
#   toutes_les_montures                     débloque toutes les montures (tests)
class Interpreter
  def donner_monture(id, message: true)
    mount = Montures.mount(id)
    unless mount
      log_error("Montures : monture #{id.inspect} introuvable") if respond_to?(:log_error, true)
      return false
    end
    list = Montures.data['unlocked']
    list << mount['id'] unless list.include?(mount['id'])
    if message
      Montures.play_cry(mount)
      message(Montures.t("#{Montures.name(mount)} vous rejoint comme monture !", "#{Montures.name(mount)} joined you as a mount!"))
    end
    return true
  end
  alias give_mount donner_monture

  def retirer_monture(id)
    Montures.dismount if Montures.current && Montures.current['id'] == id.to_s && !$game_player.surfing?
    Montures.data['unlocked'].delete(id.to_s)
    return true
  end
  alias remove_mount retirer_monture

  def monture?(id)
    return Montures.unlocked?(id)
  end
  alias mount? monture?

  def monter(id = nil)
    mount = id ? Montures.mount(id) : Montures.quick_mount
    return false unless mount && Montures.unlocked?(mount['id'])
    return true if Montures.current && Montures.current['id'] == mount['id']
    return false if Montures.refusal(mount)

    return Montures.ride(mount, cry: true)
  end
  alias ride_mount monter

  def descendre
    return Montures.leave.nil?
  end
  alias dismount descendre

  def monte?
    return Montures.riding?
  end
  alias riding? monte?

  def monture_actuelle
    return Montures.current&.fetch('id')
  end

  def roue_montures
    $scene.call_scene(GamePlay::MonturesWheel)
  end

  def appli_monture
    $scene.call_scene(GamePlay::MonturesApp)
  end

  def toutes_les_montures
    Montures.data['unlocked'] = Montures.mounts.map { |m| m['id'] }
    return true
  end
end
