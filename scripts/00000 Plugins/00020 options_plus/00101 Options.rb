# Options en plus : valeurs enregistrées dans $options et définition des options du menu Options de PSDK
#
# GamePlay::Options::PREDEFINED_OPTIONS : { nom => [nom, type, valeurs, textes des valeurs, titre, description, réglage] }
# Le « réglage » est lu / écrit sur $options (getter pj_xxx, setter pj_xxx=).
module PFM
  class Options
    # @return [Boolean] Multi Exp. : toute l'équipe gagne de l'expérience
    def pj_multi_exp
      return @pj_multi_exp.nil? ? OptionsPlus.setting('multi_exp_default') != false : @pj_multi_exp
    end

    def pj_multi_exp=(value)
      @pj_multi_exp = value ? true : false
    end

    # @return [Boolean] Sauvegarde automatique à chaque changement de carte
    def pj_autosave
      return @pj_autosave.nil? ? OptionsPlus.setting('autosave_default') == true : @pj_autosave
    end

    def pj_autosave=(value)
      @pj_autosave = value ? true : false
    end
  end
end

module GamePlay
  class Options
    pj_options = {
      pj_multi_exp: [:pj_multi_exp, :choice, [true, false], [%i[pj_option_text on], %i[pj_option_text off]],
                     %i[pj_option_text multi_exp_name], %i[pj_option_text multi_exp_desc], :pj_multi_exp],
      pj_autosave: [:pj_autosave, :choice, [true, false], [%i[pj_option_text on], %i[pj_option_text off]],
                    %i[pj_option_text autosave_name], %i[pj_option_text autosave_desc], :pj_autosave]
    }
    if PREDEFINED_OPTIONS.frozen?
      merged = PREDEFINED_OPTIONS.merge(pj_options).freeze
      remove_const(:PREDEFINED_OPTIONS)
      const_set(:PREDEFINED_OPTIONS, merged)
    else
      PREDEFINED_OPTIONS.merge!(pj_options)
    end
  end
end
