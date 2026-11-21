# Télé : commandes d'évent (Script)
#
#   tele_regarder                          -> ouvre la télé (choix de la chaîne) ; vrai si un programme a été regardé jusqu'au bout
#   tele_regarder(3)                       -> ouvre directement la chaîne 3 (de 1 à 8)
#   tele_diffuser('aide', 3, 'Astuce', 2, 'Texte de la page 1', 'Texte de la page 2')
#                                          -> ajoute (ou remplace) un programme : id, chaîne 1-8, titre, présentateur 1-5, pages
#   tele_retirer('aide')                   -> retire un programme diffusé
#   tele_programmes(3)                     -> nombre de programmes (de la chaîne 3, ou de toutes sans argument)
#   tele_nouveau?(3)                       -> vrai s'il y a un programme pas encore regardé (de la chaîne 3, ou de toutes)
#   tele_vu?('aide')                       -> vrai si le programme a été regardé jusqu'au bout
# Le titre et les pages peuvent être des tableaux [français, anglais].
class Interpreter
  # @param channel [Integer, nil] chaîne (1 à 8)
  # @return [Boolean]
  def tele_regarder(channel = nil)
    watched = false
    $scene.call_scene(GamePlay::TV, channel) { |scene| watched = scene.watched }
    @wait_count = 2
    return watched
  end

  # @param id [String, Symbol]
  # @param channel [Integer] 1 à 8
  # @param title [String, Array<String>]
  # @param presenter [Integer] 1 à 5
  # @param pages [Array<String, Array<String>>]
  # @return [Boolean]
  def tele_diffuser(id, channel, title, presenter, *pages)
    pages = pages.first if pages.size == 1 && pages.first.is_a?(Array) && pages.first.first.is_a?(Array)
    return Television.broadcast(id, channel, title, presenter, pages)
  end

  # @param id [String, Symbol]
  # @return [Boolean]
  def tele_retirer(id)
    return Television.withdraw(id)
  end

  # @param channel [Integer, nil] chaîne (1 à 8)
  # @return [Integer]
  def tele_programmes(channel = nil)
    return channel ? Television.channel_programs(channel.to_i - 1).size : Television.programs.size
  end

  # @param channel [Integer, nil] chaîne (1 à 8)
  # @return [Boolean]
  def tele_nouveau?(channel = nil)
    return Television.unseen_count(channel ? channel.to_i - 1 : nil) > 0
  end

  # @param id [String, Symbol]
  # @return [Boolean]
  def tele_vu?(id)
    program = Television.find(id)
    return program ? Television.seen?(program) : false
  end
end
