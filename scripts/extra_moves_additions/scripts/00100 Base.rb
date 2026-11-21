# Extra Moves Additions : outils communs. Chaque capacité a son fichier (00101 et suivants) ; pour en ajouter une :
# crée un fichier, une classe de capacité, enregistre-la avec Move.register(:s_extra_xxx, Classe), puis mets cette Fonction
# dans la capacité sous Studio (ou ajoute-la à tools/pokengine/appliquer_capacites_extra.py).
# Les erreurs d'une capacité sont attrapées et écrites dans le journal : un effet cassé ne bloque jamais le combat.
module ExtraMovesAdditions
  module_function

  def log_error(where, error)
    text = "[ExtraMovesAdditions] #{where} : #{error.class} #{error.message}"
    Kernel.respond_to?(:log_error, true) ? Kernel.send(:log_error, text) : puts(text)
  end

  def text(fr, en)
    return $options.language.to_s == 'fr' ? fr : en
  rescue StandardError
    return en
  end
end
