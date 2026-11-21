# Souvenirs : commandes d'évènement (Script)
#   donner_souvenir(0, :rainy_mark)         donne un ruban ou un insigne au Pokémon n° 0 de l'équipe
#   retirer_souvenir(0, :rainy_mark)        le retire
#   souvenir?(0, :rainy_mark)               le Pokémon l'a-t-il ?
#   donner_titre(0, :champion)              titre du Pokémon (il reçoit le souvenir s'il ne l'a pas) ; nil le retire
#   titre_pokemon(0)                        « Pikachu l'Affamé » (ou le surnom seul)
#   taille_pokemon(0)                       taille (0 à 255) ; taille_pokemon(0, 255) la change (insignes Mini/Colosse)
#   insigne_sauvage(0)                      tirage d'un insigne comme un Pokémon sauvage
#   nombre_souvenirs(0)                     nombre de rubans et d'insignes
#   choisir_anniversaire                    le joueur choisit sa date d'anniversaire (insigne Destin)
#   definir_anniversaire(14, 2)             anniversaire réglé par l'évènement (jour, mois)
#   anniversaire?                           c'est l'anniversaire du joueur aujourd'hui
#   debug_souvenirs                         menu de test (donner des insignes, des rubans, tout retirer)
class Interpreter
  def donner_souvenir(index, memento)
    pokemon = $actors[index]
    return false unless pokemon && PFM::RIBBONS_DATA[memento.to_sym]

    pokemon.add_ribbon(memento.to_sym)
    return pokemon.ribbon?(memento.to_sym)
  end
  alias donner_insigne donner_souvenir
  alias donner_ruban donner_souvenir

  def retirer_souvenir(index, memento)
    pokemon = $actors[index]
    return false unless pokemon

    pokemon.remove_ribbon(memento.to_sym)
    return true
  end

  def souvenir?(index, memento)
    return $actors[index]&.ribbon?(memento.to_sym) ? true : false
  end

  def donner_titre(index, memento)
    pokemon = $actors[index]
    return false unless pokemon
    return pokemon.set_title(nil) if memento.nil?

    pokemon.add_ribbon(memento.to_sym) unless pokemon.ribbon?(memento.to_sym)
    return pokemon.set_title(memento.to_sym)
  end

  def titre_pokemon(index)
    return $actors[index]&.given_name_with_title.to_s
  end

  def taille_pokemon(index, value = nil)
    pokemon = $actors[index]
    return 0 unless pokemon
    return pokemon.pj_scale if value.nil?

    pokemon.pj_scale = value
    Mementos.size_mark(pokemon)
    return pokemon.pj_scale
  end

  def insigne_sauvage(index)
    pokemon = $actors[index]
    return nil unless pokemon

    mark = Mementos.roll_wild_mark(false)
    pokemon.add_ribbon(mark) if mark
    return mark
  end

  def nombre_souvenirs(index)
    return $actors[index]&.ribbons&.size.to_i
  end

  def choisir_anniversaire
    t = Mementos
    months = Array.new(12) { |i| t.month_name(i + 1) }
    loop do
      month = message(t.t('Quel est le mois de ton anniversaire ?', 'Which month is your birthday in?'), 0, *months) + 1
      days = Array.new(t.days_in_month(month)) { |i| (i + 1).to_s }
      day = choose_in_list(t.t("Quel jour de #{t.month_name(month)} ?", "Which day in #{t.month_name(month)}?"), days) + 1
      sentence = t.t("Ton anniversaire est le #{day} #{t.month_name(month).downcase}, c'est bien ça ?",
                     "So, your birthday is #{t.month_name(month)} #{day}, correct?")
      next unless message(sentence, 2, t.t('Oui', 'Yes'), t.t('Non', 'No')) == 0

      t.set_birthday(day, month)
      return [day, month]
    end
  end

  def definir_anniversaire(day, month)
    Mementos.set_birthday(day, month)
    return true
  end

  def anniversaire?
    return Mementos.anniversary?
  end

  # Menu de test : insignes et rubans sur le Pokémon n° 0
  def debug_souvenirs(index = 0)
    pokemon = $actors[index]
    return false unless pokemon

    t = Mementos
    choices = [t.t('Insigne sauvage au hasard', 'Random wild mark'), t.t('Tous les insignes', 'All marks'),
               t.t('Tous les rubans', 'All ribbons'), t.t('Tout retirer', 'Remove all'), t.t('Retour', 'Back')]
    case message(t.t("Souvenirs de #{pokemon.given_name} (#{pokemon.ribbons.size})", "#{pokemon.given_name}'s mementos (#{pokemon.ribbons.size})"), 5, *choices)
    when 0
      mark = Mementos::MARK_CATEGORIES.flat_map { |c| Mementos.of_category(c) }.sample
      pokemon.add_ribbon(mark)
      message(PFM::RIBBONS_DATA[mark].name)
    when 1 then Mementos::MARK_CATEGORIES.flat_map { |c| Mementos.of_category(c) }.each { |s| pokemon.add_ribbon(s) }
    when 2 then PFM::RIBBONS_DATA.each_key { |s| pokemon.add_ribbon(s) unless Mementos.mark?(s) }
    when 3
      pokemon.ribbons.clear
      pokemon.title_ribbon = nil
    end
    return true
  end

  private

  # Liste de choix qui défile (jours du mois)
  def choose_in_list(text, list)
    page = 0
    loop do
      slice = list[page * 8, 8]
      extra = []
      extra << Mementos.t('Suivants', 'Next') if (page + 1) * 8 < list.size
      extra << Mementos.t('Précédents', 'Previous') if page > 0
      choice = message(text, 0, *slice, *extra)
      return page * 8 + choice if choice < slice.size

      page += extra[choice - slice.size] == Mementos.t('Suivants', 'Next') ? 1 : -1
    end
  end
end
