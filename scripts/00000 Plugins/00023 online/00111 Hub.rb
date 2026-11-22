# encoding: utf-8
# Jeu en ligne — menu principal (commande d'évènement : online_menu). À brancher sur un PNJ, un objet ou un bouton du téléphone.
module Online
  module Game
    module_function

    # Menu central : adapte les entrées à ce qui est disponible (le mode serveur donne accès aux amis et au monde en ligne)
    # @return [Boolean]
    def hub
      unless Online.enabled?
        say(Online.t('Le jeu en ligne est désactivé.', 'Online play is disabled.'))
        return false
      end
      loop do
        entries = [[Online.t('Échanger', 'Trade'), :trade], [Online.t('Combattre', 'Battle'), :battle]]
        entries << [Online.t('Amis et classements', 'Friends and ranks'), :social] << [Online.t('Monde en ligne', 'Online world'), :world] if Online.server?
        entries << [Online.t('Quitter', 'Quit'), :quit]
        choice = entries[ask(Online.t('Jeu en ligne', 'Online play'), *entries.map(&:first))]&.last
        case choice
        when :trade then return true if trade
        when :battle then return true if battle_menu
        when :social then social
        when :world then world
        else break
        end
      end
      return true
    end

    # @return [Boolean] un combat a démarré (le menu se ferme pour laisser la place au combat)
    def battle_menu
      choice = ask(Online.t('Quel combat ?', 'Which battle?'), Online.t('Temps réel', 'Live'), Online.t("Défi d'équipe", 'Team challenge'), Online.t('Retour', 'Back'))
      return pvp if choice == 0
      return duel if choice == 1

      return false
    end
  end
end

class Interpreter
  # Menu du jeu en ligne (échange, combats, amis, monde)
  def online_menu
    result = Online::Game.hub
    @wait_count = 2
    return result
  end
end
