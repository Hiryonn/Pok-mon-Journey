# encoding: utf-8
# Échange Miracle : commandes d'évènement (voir 00100 Configuration.rb)
class Interpreter
  def echange_miracle
    if EchangeMiracle.limit_reached?
      $scene.display_message_and_wait(EchangeMiracle.t('Tu as déjà fait tous tes échanges aujourd’hui.', 'You have used all your trades for today.'))
      return false
    end

    index = -1
    $scene.call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
    return false if index.nil? || index < 0

    pokemon = $actors[index]
    return false unless pokemon

    reason = EchangeMiracle.refusal(pokemon)
    if reason
      $scene.display_message_and_wait(reason)
      return false
    end
    ask = EchangeMiracle.t("Envoyer #{pokemon.given_name} ?", "Send #{pokemon.given_name}?")
    return false unless $scene.display_message(ask, 1, EchangeMiracle.t('Oui', 'Yes'), EchangeMiracle.t('Non', 'No')).to_i == 0

    $scene.display_message_and_wait(EchangeMiracle.t('Connexion à l’Échange Miracle…', 'Connecting to Wonder Trade…'))
    result = EchangeMiracle.trade(index)
    return false unless result

    message = EchangeMiracle.localized(EchangeMiracle.fetch(result[:trainer], 'message')) || '%s'
    message = '%s' if message.to_s.empty?
    $scene.display_message_and_wait(format(message, result[:got].name))
    $scene.display_message_and_wait(EchangeMiracle.t("#{result[:got].name} N.#{result[:got].level} rejoint ton équipe !", "#{result[:got].name} Lv.#{result[:got].level} joins your team!"))
    return true
  end

  def echange_miracle_possible?
    return EchangeMiracle.possible?
  end

  def echanges_miracle_nombre
    return EchangeMiracle.state['count'].to_i
  end

  def echange_miracle_dernier
    return EchangeMiracle.last_name
  end
end
