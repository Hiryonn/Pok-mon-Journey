# encoding: utf-8
# Failles spatio-temporelles : commandes d'évènement
#   faille_ouvrir    fait apparaître une faille près du joueur (renvoie true si elle est apparue)
#   faille_active?   une zone distordue est ouverte
#   faille_fermer    referme la zone
class Interpreter
  # Appelée par la faille elle-même
  def faille_entrer
    return unless Failles.setting('enabled')

    display_message_and_wait(Failles.t('Une faille spatio-temporelle ! Elle t’aspire dans une zone distordue...',
                                       'A space-time rift! It pulls you into a distorted zone...'))
    Failles.enter
    @wait_count = 2
  end

  def faille_rencontre(id)
    Failles.encounter(self, id)
    @wait_count = 2
  end

  def faille_objet(id)
    Failles.pickup(self, id)
  end

  def faille_ouvrir
    return Failles.open_faille
  end

  def faille_active?
    return Failles.active?
  end

  def faille_fermer
    Failles.close_zone(true)
  end
end
