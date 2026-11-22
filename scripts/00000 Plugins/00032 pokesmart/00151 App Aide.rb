# PokeSmart : appli Aide (tutoriels en jeu)
#
# L'appli ouvre une scène à part (GamePlay::Aide, voir 00152 Scene Aide.rb) : le téléphone se range et laisse la place
# à une interface fixe avec la liste des tutoriels, leur texte et une image d'exemple.
# Le contenu est dans 00150 Aide - Contenu.rb (HELP_CATEGORIES). Commande d'évènement : aide(:combat)
module UI
  module PokeSmart
    module_function

    # @param text [Array<String>, String] [français, anglais, image] ou texte seul
    # @return [String]
    def help_text(text)
      return text.to_s unless text.is_a?(Array)

      return (text[french? ? 0 : 1] || text[0]).to_s
    end

    # @param page [Array<String>] page [français, anglais, image facultative]
    # @return [String, nil] image d'exemple (dans graphics/interface/aide/), sans l'extension
    def help_image(page)
      name = page.is_a?(Array) ? page[2] : nil
      return name.to_s.empty? ? nil : "#{HELP_IMAGE_DIR}#{name}"
    end

    # @return [Array<Hash>] rubriques de l'aide (HELP_CATEGORIES)
    def help_categories
      return HELP_CATEGORIES.reject { |category| category[:topics].to_a.empty? }
    end
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Aide : ouvre la scène des tutoriels
      def open_help
        call_scene(GamePlay::Aide)
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_help) { UI::PokeSmart::HELP_APP } unless ACTION_LIST.include?(:open_help)
    end
  end
end

# Commande d'évènement (Script) : aide  /  aide(:combat)  (id de la rubrique)
class Interpreter
  def aide(category = nil)
    $scene.call_scene(GamePlay::Aide, category)
    @wait_count = 2
    return true
  end
  alias ouvrir_aide aide
end
