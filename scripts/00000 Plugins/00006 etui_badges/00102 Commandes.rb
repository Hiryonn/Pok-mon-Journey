# Étui à badges : commandes d'évènement (Script) et appli du téléphone
#
#   etui_badges                 -> ouvre l'étui (région du premier badge qui manque)
#   etui_badges(2)              -> ouvre l'étui sur la région 2
#   obtenir_badge(:boulder)     -> donne le badge et montre « Badge obtenu ! » (obtenir_badge(:boulder, false) : sans écran)
#   retirer_badge(:boulder)     -> retire le badge
#   badge?(:boulder)            -> true si le badge est obtenu
#   nombre_badges               -> nombre de badges obtenus (nombre_badges(1) : dans la région 1)
class Interpreter
  def etui_badges(region = nil)
    $scene.call_scene(GamePlay::EtuiBadges, region)
    @wait_count = 2
    return true
  end
  alias ouvrir_etui_badges etui_badges

  def obtenir_badge(id, show = true)
    badge = ::EtuiBadges.badge(id)
    return log_error("Étui à badges : badge #{id} inconnu") && false unless badge

    ::EtuiBadges.give(badge)
    if show
      $scene.call_scene(GamePlay::EtuiBadges, nil, obtain: id)
      @wait_count = 2
    end
    return true
  end

  def retirer_badge(id)
    badge = ::EtuiBadges.badge(id)
    ::EtuiBadges.take(badge) if badge
    return true
  end

  def badge?(id)
    return ::EtuiBadges.obtained?(::EtuiBadges.badge(id))
  end

  def nombre_badges(region = nil)
    return ::EtuiBadges.count(region)
  end
end

# Appli « Badges » du téléphone (PokeSmart : icône icon_badges) ; dans le menu de PSDK, un bouton de plus
module GamePlay
  class Menu
    def open_badges
      call_scene(GamePlay::EtuiBadges)
    end

    register_button(:open_badges) { !::EtuiBadges.all.empty? } unless ACTION_LIST.include?(:open_badges)
  end
end
