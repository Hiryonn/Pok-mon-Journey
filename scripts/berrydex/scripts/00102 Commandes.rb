# Berrydex : commandes d'évènement (Script)
#
#   berrydex                          -> ouvre le Berrydex (alias ouvrir_berrydex)
#   berrydex(:oran_berry)             -> ouvre le Berrydex sur cette baie
#   berrydex_enregistrer(:oran_berry, :pecha_berry)  -> marque des baies comme trouvées
#   berrydex_tout_enregistrer         -> toutes les baies trouvées
#   berrydex_trouvees                 -> nombre de baies trouvées
#   berrydex_trouvee?(:oran_berry)    -> true si la baie est trouvée
class Interpreter
  def berrydex(start = nil)
    $scene.call_scene(GamePlay::Berrydex, start)
    @wait_count = 2
    return true
  end
  alias ouvrir_berrydex berrydex

  def berrydex_enregistrer(*berries)
    berries.flatten.each { |db| Berrydex.register(db) }
    return true
  end

  def berrydex_tout_enregistrer
    Berrydex.list.each { |db| Berrydex.register(db) }
    return true
  end

  # @return [Integer]
  def berrydex_trouvees
    return Berrydex.found_count
  end

  def berrydex_trouvee?(db_symbol)
    return Berrydex.found?(db_symbol)
  end
end
