# encoding: utf-8
# Pique-nique : commandes d'évènement (voir 00100 Configuration.rb)
class Interpreter
  # Menu du pique-nique
  def pique_nique
    loop do
      eggs = PiqueNique.eggs
      plural = eggs > 1 ? 's' : ''
      entries = [
        [PiqueNique.active? ? PiqueNique.t('Pique-nique en cours', 'Picnic in progress') : PiqueNique.t('Installer le pique-nique', 'Set up the picnic'),
         -> { PiqueNique.install unless PiqueNique.active? }],
        [PiqueNique.t('Préparer un sandwich', 'Make a sandwich'), -> { pique_nique_sandwichs }],
        [PiqueNique.t("Panier (#{eggs} œuf#{plural})", "Basket (#{eggs} egg#{plural})"), -> { pique_nique_panier }]
      ]
      entries << [PiqueNique.t('Jouer avec les Pokémon', 'Play with the Pokémon'), -> { poke_recre }] if respond_to?(:poke_recre)
      entries << [PiqueNique.t('Ranger', 'Pack up'), nil]
      intro = PiqueNique.meal_name ? PiqueNique.t("Sandwich : #{PiqueNique.meal_name}", "Sandwich: #{PiqueNique.meal_name}") : PiqueNique.t('Pique-nique', 'Picnic')
      choice = $scene.display_message(intro, 1, *entries.map(&:first)).to_i
      action = entries[choice] && entries[choice].last
      return true unless action

      action.call
    end
  end

  def pique_nique_panier
    got = PiqueNique.collect
    return got if got.zero?

    $scene.display_message_and_wait(PiqueNique.t("#{got} œuf#{got > 1 ? 's' : ''} récupéré#{got > 1 ? 's' : ''} !", "#{got} egg#{got > 1 ? 's' : ''} collected!"))
    return got
  end

  def pique_nique_sandwichs
    list = PiqueNique.recipes
    return false if list.empty?

    names = list.map { |r| "#{PiqueNique.recipe_name(r)}#{PiqueNique.possible?(PiqueNique.fetch(r, 'id')) ? '' : ' (-)'}" }
    index = $scene.display_message(PiqueNique.t('Quel sandwich ?', 'Which sandwich?'), 1, *names, PiqueNique.t('Retour', 'Back')).to_i
    return false if index >= list.size

    id = PiqueNique.fetch(list[index], 'id')
    if PiqueNique.cook(id)
      $scene.display_message_and_wait(PiqueNique.t("#{PiqueNique.recipe_name(list[index])} : délicieux !", "#{PiqueNique.recipe_name(list[index])}: delicious!"))
      return true
    end
    $scene.display_message_and_wait(PiqueNique.t("Il manque des ingrédients pour ce sandwich.", "You're missing ingredients for that sandwich."))
    return false
  end

  def pique_nique_installer
    PiqueNique.install
  end

  def pique_nique_actif?
    return PiqueNique.active?
  end

  def pique_nique_oeufs
    return PiqueNique.eggs
  end

  def panier_recuperer
    return PiqueNique.collect
  end

  def sandwich_cuisiner(id)
    return PiqueNique.cook(id)
  end

  def sandwich_possible?(id)
    return PiqueNique.possible?(id)
  end

  def sandwich_actif
    return PiqueNique.meal_name
  end

  def pique_nique_compatibles?
    return !PiqueNique.pair.nil?
  end
end
