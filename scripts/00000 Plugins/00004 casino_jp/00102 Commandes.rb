# Casino JP : commande d'évent (Script)
#
#   casino_jp          -> la machine à sous « version japonaise » (vitesse 2)
#   casino_jp(3)       -> idem, rouleaux plus rapides
# (à mettre à la place de casino(:slotmachine, 2) dans l'évent de la machine)
class Interpreter
  # @param speed [Integer] vitesse des rouleaux
  def casino_jp(speed = 2)
    $scene.call_scene(GamePlay::CasinoJpScene, speed)
    @wait_count = 2
    return true
  end
end
