# Tour de Combat : série de victoires d'affilée (écran de sélection d'équipe du Tournoi), qui rapporte des Points Combat
# (PCo) tous les « rounds » victoires. Les PCo sont une monnaie du plugin Magasins (kind « points », id « pco »), à
# dépenser dans un comptoir (Studio : Magasins > Monnaies).
#
# Tours réglés dans Data/configs/plugins/tournois.json, clé « towers » :
#   { id, name { fr, en }, rounds (victoires par palier, 7), tiers [[dresseurs du 1er palier], [2e palier]…] (le dernier
#     se répète), pco_base (PCo du 1er palier), pco_step (PCo en plus à chaque palier), pco_max, currency ('pco'),
#     ask_continue (true : demander s'il faut continuer à chaque palier), rules { pick, max_level, items… (règles du Tournoi) } }
#
# Commandes d'évènement (modèle d'un évènement « Tour de Combat », avec une étiquette « debut ») :
#   tour_demarrer(:tour_pj)       commence une série (équipe soignée selon les règles)
#   [étiquette debut]
#   tour_suivant                  choix de l'équipe puis combat contre le dresseur suivant
#   tour_resultat                 à appeler juste après : compte la victoire ou termine la série
#   si tour_perdu?                -> tour_terminer, puis quitter l'évènement
#   si tour_palier?               -> tour_recompense (donne les PCo) ; si !tour_continuer? -> tour_terminer, quitter
#   aller à l'étiquette debut
#   tour_serie / tour_record(:tour_pj) / pco / ajouter_pco(10) / depenser_pco(5)
module Tournoi
  module Tour
    module_function

    def tower(id)
      return Array(Tournoi.config.towers).find { |t| Tournoi.fetch(t, 'id').to_s == id.to_s }
    end

    # État de la partie (sauvegardé)
    def state
      game = PFM.game_state
      return game.instance_variable_get(:@pj_tour) || game.instance_variable_set(:@pj_tour, { 'records' => {} })
    end

    def current
      return tower(state['id'])
    end

    def record(id)
      return state['records'][id.to_s] ||= { 'best' => 0, 'played' => 0, 'pco' => 0 }
    end

    def streak
      return state['streak'].to_i
    end

    def rounds(t = current)
      value = Tournoi.fetch(t, 'rounds')
      return value.nil? ? 7 : [value.to_i, 1].max
    end

    def set_index(streak_value = streak)
      return streak_value / rounds
    end

    def currency_id(t = current)
      value = Tournoi.fetch(t, 'currency').to_s
      return value.empty? ? 'pco' : value
    end

    # --- Points Combat ---------------------------------------------------------------------------------
    def pco(id = 'pco')
      return defined?(::Magasins) ? ::Magasins.funds(::Magasins.currency(id)) : 0
    end

    def add_pco(amount, id = 'pco')
      return 0 unless defined?(::Magasins)

      ::Magasins.receive(::Magasins.currency(id), amount.to_i)
      return amount.to_i
    end

    def spend_pco(amount, id = 'pco')
      return false unless defined?(::Magasins) && pco(id) >= amount.to_i

      ::Magasins.pay(::Magasins.currency(id), amount.to_i)
      return true
    end

    # @return [Integer] PCo du palier qui vient d'être atteint
    def reward_amount(t = current)
      base = Tournoi.fetch(t, 'pco_base')
      base = 3 if base.nil?
      step = Tournoi.fetch(t, 'pco_step').to_i
      step = 1 if Tournoi.fetch(t, 'pco_step').nil?
      amount = base.to_i + step * [set_index - 1, 0].max
      max = Tournoi.fetch(t, 'pco_max').to_i
      return max > 0 ? [amount, max].min : amount
    end

    # --- Série -------------------------------------------------------------------------------------
    def start(id)
      t = tower(id)
      unless t
        log_error("Tour de Combat : tour #{id} inconnu") if respond_to?(:log_error, true)
        return false
      end
      st = state
      st.merge!('id' => id.to_s, 'streak' => 0, 'active' => true, 'rewarded' => 0, 'pending' => false, 'last_trainer' => nil, 'result' => nil)
      Tournoi.heal($actors) if Tournoi.rules(nil, Tournoi.fetch(t, 'rules') || {})['heal']
      return true
    end

    # @return [Symbol, String, nil] dresseur du prochain combat
    def pick_trainer(t = current)
      tiers = Array(Tournoi.fetch(t, 'tiers'))
      tier = Array(tiers[[set_index, tiers.size - 1].min]).select { |tr| Tournoi.trainer_exists?(tr) }
      tier = tier.reject { |tr| tr.to_s == state['last_trainer'].to_s } if tier.size > 1
      return tier.sample
    end

    def next_battle
      t = current
      return false unless t && state['active']

      trainer = pick_trainer(t)
      return false unless trainer

      state['last_trainer'] = trainer.to_s
      rules = Tournoi.rules(nil, Tournoi.fetch(t, 'rules') || {})
      started = Tournoi.selection_battle(trainer, rules)
      state['pending'] = started ? true : false
      return state['pending']
    end

    # @return [Symbol] :win, :lost
    def result
      st = state
      won = st['pending'] && Tournoi.last_selection == 0
      st['pending'] = false
      if won
        st['streak'] = streak + 1
        rec = record(st['id'])
        rec['best'] = [rec['best'], streak].max
        st['result'] = :win
      else
        st['result'] = :lost
      end
      return st['result']
    end

    def lost?
      return state['result'] == :lost
    end

    # Palier atteint et pas encore récompensé
    def milestone?
      return streak > 0 && streak % rounds == 0 && state['rewarded'].to_i < streak
    end

    def reward
      t = current
      amount = reward_amount(t)
      add_pco(amount, currency_id(t))
      state['rewarded'] = streak
      rec = record(state['id'])
      rec['pco'] += amount
      name = Tournoi.local(Tournoi.fetch(t, 'name'), 'Tour')
      $scene.display_message_and_wait(Tournoi.t("#{streak} victoires d'affilée ! Vous gagnez #{amount} PCo.", "#{streak} wins in a row! You earn #{amount} BP."))
      return amount
    end

    def ask_continue
      t = current
      return true if Tournoi.fetch(t, 'ask_continue') == false

      index = $scene.display_message(Tournoi.t('Continuer la série ?', 'Keep going?'), 1, Tournoi.t('Oui', 'Yes'), Tournoi.t('Non', 'No')).to_i
      return index == 0
    end

    def finish
      st = state
      return unless st['active']

      st['active'] = false
      rec = record(st['id'])
      rec['played'] += 1
      Tournoi.heal($actors) if st['streak'].to_i >= 0
      $scene.display_message_and_wait(Tournoi.t("Série terminée : #{st['streak']} victoire(s).", "Run over: #{st['streak']} win(s)."))
    end
  end
end

class Interpreter
  def tour_demarrer(id)
    return Tournoi::Tour.start(id)
  end

  def tour_suivant
    ok = Tournoi::Tour.next_battle
    @wait_count = 2 if ok
    return ok
  end

  def tour_resultat
    return Tournoi::Tour.result
  end

  def tour_perdu?
    return Tournoi::Tour.lost?
  end

  def tour_palier?
    return Tournoi::Tour.milestone?
  end

  def tour_recompense
    return Tournoi::Tour.reward
  end

  def tour_continuer?
    return Tournoi::Tour.ask_continue
  end

  def tour_terminer
    return Tournoi::Tour.finish
  end

  def tour_serie
    return Tournoi::Tour.streak
  end

  def tour_record(id = Tournoi::Tour.state['id'])
    return Tournoi::Tour.record(id)['best']
  end

  def pco(id = 'pco')
    return Tournoi::Tour.pco(id)
  end

  def ajouter_pco(amount, id = 'pco')
    return Tournoi::Tour.add_pco(amount, id)
  end

  def depenser_pco(amount, id = 'pco')
    return Tournoi::Tour.spend_pco(amount, id)
  end
end
