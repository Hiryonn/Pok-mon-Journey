# Modes de jeu : Difficile, Extrême, Nuzlocke et Randomizer, choisis au début de la partie.
#
#   Difficile : plafond de niveau selon les badges (seul ce mode en a un), dresseurs plus forts, style de combat « Set » forcé
#   Extrême   : Difficile + aucun objet du sac contre les dresseurs
#   Nuzlocke  : 1re rencontre par zone, clauses chromatique et doublons, surnom obligatoire, mort définitive (cimetière)
#   Randomizer: Pokémon offerts (starters…), rencontres sauvages et équipes des dresseurs (niveaux conservés), selon une graine
#
# Réglages : Data/configs/plugins/modes_jeu.json (Studio : Réglages du jeu > Modes de jeu), clé « settings » :
#   level_caps            plafond de niveau selon le nombre de badges (0 badge, 1 badge, …) ; le dernier vaut pour la suite
#   trainer_bonus         niveaux ajoutés aux Pokémon des dresseurs en Difficile (extreme_trainer_bonus en plus en Extrême)
#   cap_block_exp         true : pas d'expérience au plafond ; false : seulement pas de montée au-dessus
#   extreme_block_wild    true : objets aussi interdits dans les combats sauvages (Poké Balls comprises)
#   nuzlocke_*            clauses (first_encounter, shiny_clause, dupes_clause, nickname, permadeath, wipe)
#   randomizer_*          wild / trainers / gifts, exclude (db_symbols jamais tirés), seed (0 = au hasard au choix des modes)
module Configs
  class ModesJeuConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:modes_jeu, 'plugins/modes_jeu', :json, false, ModesJeuConfig)
end

module ModesJeu
  CONFIG_FILE = 'Data/configs/plugins/modes_jeu.json'
  DEFAULTS = {
    'level_caps' => [14, 19, 24, 29, 34, 39, 44, 49, 100], 'cap_block_exp' => true,
    'trainer_bonus' => 2, 'extreme_trainer_bonus' => 2, 'extreme_block_wild' => false,
    'nuzlocke_first_encounter' => true, 'nuzlocke_shiny_clause' => true, 'nuzlocke_dupes_clause' => true,
    'nuzlocke_nickname' => true, 'nuzlocke_permadeath' => true, 'nuzlocke_wipe' => 'revive_last',
    'nuzlocke_revive_item' => 'nuzlocke_revive', 'nuzlocke_nicknames' => %w[Ombre Cendre Rune Brume Écho Glas],
    'randomizer_wild' => true, 'randomizer_trainers' => true, 'randomizer_gifts' => true,
    'randomizer_exclude' => [], 'seed' => 0,
    'lock_choice' => true,
    'overkill_enabled' => true, 'overkill_threshold' => 50, 'overkill_exp_percent' => 25, 'overkill_loyalty' => 1,
    'overkill_message' => true
  }.freeze
  TEXTS = {
    normal: ['Normal', 'Normal'], hard: ['Difficile', 'Hard'], extreme: ['Extrême', 'Extreme'],
    nuzlocke: ['Nuzlocke', 'Nuzlocke'], randomizer: ['Randomizer', 'Randomizer'],
    ask_diff: ['Quelle difficulté ?', 'Which difficulty?'],
    ask_nuz: ['Activer le mode Nuzlocke ?', 'Enable Nuzlocke mode?'],
    ask_rand: ['Activer le Randomizer ?', 'Enable the Randomizer?'],
    yes: ['Oui', 'Yes'], no: ['Non', 'No'],
    confirm: ['Ces modes ne pourront plus être changés. Confirmer ?', 'These modes cannot be changed later. Confirm?'],
    cap_line: ['Niveau max. : ', 'Level cap: '],
    cap_hit: ["%s ne peut plus progresser : plafond de niveau atteint (niv. %d).", '%s cannot grow: level cap reached (Lv. %d).'],
    no_items: ["Mode Extrême : les objets sont interdits en combat !", 'Extreme mode: items are banned in battle!'],
    nuz_block_zone: ['Nuzlocke : on a déjà rencontré un Pokémon ici, la capture est impossible.',
                     'Nuzlocke: you already had an encounter here, no capture possible.'],
    nuz_block_dupe: ['Nuzlocke : doublon, il ne compte pas… mais ne peut pas être capturé.',
                     'Nuzlocke: duplicate, it does not count… and cannot be caught.'],
    nuz_dead: ['%s est tombé au combat… Repose en paix.', '%s fell in battle… Rest in peace.'],
    nuz_wipe: ['Tous vos Pokémon sont tombés ! Le dernier est ranimé de justesse.', 'Your whole team fell! The last one is barely revived.'],
    grave_empty: ['Le cimetière est vide.', 'The graveyard is empty.'],
    grave_pick: ['Qui ranimer ?', 'Who should be revived?'],
    grave_done: ['%s est revenu à la vie !', '%s came back to life!'],
    overkill: ['Overkill !', 'Overkill!'],
    grave_cancel: ['Annuler', 'Cancel']
  }.freeze

  module_function

  def settings
    @settings ||= begin
      if PSDK_CONFIG.release?
        Configs.modes_jeu.settings || {}
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings'] : {}
      else
        {}
      end
    rescue StandardError, ScriptError => e
      log_error("réglages illisibles (#{e.message})")
      {}
    end
  end

  def reload
    @settings = nil
  end

  def setting(key)
    value = settings[key.to_s]
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def log_error(message)
    Kernel.send(:log_error, "Modes de jeu : #{message}") if Kernel.respond_to?(:log_error, true)
  rescue StandardError
    nil
  end

  # @return [String] texte dans la langue du jeu (format : % remplacés par args)
  def text(key, *args)
    pair = TEXTS[key.to_sym] || [key.to_s, key.to_s]
    str = $options && $options.language.to_s != 'fr' ? pair[1] : pair[0]
    return args.empty? ? str : (format(str, *args) rescue str)
  end

  # --- État de la partie (sauvegardé dans $user_data) ---------------------------------------------
  def state
    return ($user_data[:pj_modes] ||= { 'chosen' => false })
  end

  def chosen?
    return state['chosen'] == true
  end

  def hard?
    return state['hard'] == true || extreme?
  end

  def extreme?
    return state['extreme'] == true
  end

  def nuzlocke?
    return state['nuzlocke'] == true
  end

  def randomizer?
    return state['randomizer'] == true
  end

  def seed
    return state['seed'].to_i
  end

  # @param hard [Boolean] @param extreme [Boolean] @param nuzlocke [Boolean] @param randomizer [Boolean]
  def choose(hard: false, extreme: false, nuzlocke: false, randomizer: false, seed: nil)
    st = state
    return false if st['chosen'] && setting('lock_choice')

    st['hard'] = hard || extreme
    st['extreme'] = extreme
    st['nuzlocke'] = nuzlocke
    st['randomizer'] = randomizer
    fixed = setting('seed').to_i
    st['seed'] = (seed || (fixed > 0 ? fixed : Random.new_seed % 2_000_000_000)).to_i
    st['chosen'] = true
    ModesJeu::Randomizer.reset if defined?(ModesJeu::Randomizer)
    return true
  end

  def summary
    list = []
    list << text(:extreme) if extreme?
    list << text(:hard) if hard? && !extreme?
    list << text(:nuzlocke) if nuzlocke?
    list << "#{text(:randomizer)} ##{seed}" if randomizer?
    return list.empty? ? text(:normal) : list.join(' + ')
  end

  def max_level
    return Configs.settings.respond_to?(:max_level) ? Configs.settings.max_level : 100
  end

  # --- Plafond de niveau (Difficile et Extrême seulement) ----------------------------------------------
  # @return [Integer] nombre de badges obtenus
  def badge_count
    return ::EtuiBadges.count if defined?(::EtuiBadges) && !::EtuiBadges.all.empty?
    return $trainer.badge_count if $trainer.respond_to?(:badge_count)

    return 0
  rescue StandardError
    return 0
  end

  # @return [Integer, nil] plafond actuel, nil si le mode n'en a pas
  def level_cap
    return nil unless hard?

    caps = Array(setting('level_caps')).map(&:to_i)
    caps = DEFAULTS['level_caps'] if caps.empty?
    return caps[[badge_count, caps.size - 1].min].clamp(1, max_level)
  end
end
