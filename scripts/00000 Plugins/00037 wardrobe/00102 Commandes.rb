# Wardrobe : commandes d'évent (Script)
#
#   ouvrir_wardrobe                 -> la salle d'essayage : choisir une tenue parmi celles du sac ; vrai si le héros a changé de tenue
#   porter_tenue(:tenue_sport)      -> le héros enfile la tenue (sans écran, même s'il ne l'a pas) ; vrai si c'est fait
#   retirer_tenue                   -> le héros retrouve son apparence d'origine
#   tenue_portee                    -> dbSymbol de la tenue portée, ou nil
#   tenue_portee?(:tenue_sport)     -> condition d'évent : cette tenue est portée
#   possede_tenue?(:tenue_sport)    -> condition d'évent : le joueur a cet objet-tenue dans son sac
#   donner_tenue(:tenue_sport)      -> ajoute l'objet-tenue au sac (une seule fois) ; vrai s'il a été ajouté
#   nombre_tenues                   -> combien de tenues le joueur peut porter
#   tenue_actuelle_en_texte         -> la tenue actuelle du héros, prête à coller dans OUTFITS (écrite dans la console)
# Les tenues sont déclarées dans « 00100 Configuration.rb » (OUTFITS).
class Interpreter
  # @return [Boolean]
  def ouvrir_wardrobe
    unless Wardrobe.ready?
      text = 'Wardrobe : les pièces du générateur sont absentes (Studio : Générateurs > Personnages > Préparer pour le jeu).'
      log_error(text) if respond_to?(:log_error, true)
      return false
    end
    changed = false
    $scene.call_scene(GamePlay::Wardrobe) { |scene| changed = scene.changed }
    @wait_count = 2
    return changed
  end

  # @param item [Symbol]
  # @return [Boolean]
  def porter_tenue(item)
    outfit = Wardrobe.find(item)
    return false unless outfit && Wardrobe.gender_ok?(outfit, Wardrobe.player_gender)

    return Wardrobe.wear(outfit)
  end

  # @return [Boolean]
  def retirer_tenue
    return Wardrobe.restore
  end

  # @return [Symbol, nil]
  def tenue_portee
    return Wardrobe.ready? ? Wardrobe.worn_item : nil
  end

  # @param item [Symbol]
  # @return [Boolean]
  def tenue_portee?(item)
    return Wardrobe.ready? && Wardrobe.worn?(item)
  end

  # @param item [Symbol]
  # @return [Boolean]
  def possede_tenue?(item)
    outfit = Wardrobe.find(item)
    return outfit ? Wardrobe.owned?(outfit) : false
  end

  # @param item [Symbol]
  # @return [Boolean] ajouté au sac
  def donner_tenue(item)
    outfit = Wardrobe.find(item)
    return false if outfit.nil? || Wardrobe.owned?(outfit)

    $bag.add_item(outfit['item'].to_sym, 1)
    return true
  end

  # @return [Integer]
  def nombre_tenues
    return Wardrobe.owned_outfits.size
  end

  # @return [String]
  def tenue_actuelle_en_texte
    text = Wardrobe.ready? ? Wardrobe.current_as_text : ''
    puts text unless text.empty?
    return text
  end
end
