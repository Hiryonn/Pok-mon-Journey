# Styles de combat de Pokémon Légendes Arceus (d'après « PLA Battle Styles » pour Essentials, de Lucidious89)
#
# Style Puissant / Style Rapide : pendant le choix de l'attaque, Y ouvre la roue des mécaniques du plugin gimmicks,
# où apparaissent Strong et Agile. Seules les capacités maîtrisées peuvent être lancées avec un
# style. Le style dure 2 tours ; ensuite le dresseur doit attendre 3 tours avant d'en reprendre un.
#   Puissant : capacités maîtrisées plus puissantes, plus précises, effets secondaires plus fréquents, changements
#              de stats d'un cran de plus, soins et contrecoups plus forts ; le Pokémon agit après les autres pendant
#              tout le style ; apeuré si un Pokémon en Style Rapide le frappe avant qu'il agisse (une fois).
#   Rapide :   capacités maîtrisées moins puissantes, changements de stats d'un cran de moins, soins plus faibles ;
#              le Pokémon agit en premier au tour où il prend le style ; il ne peut pas être apeuré.
#   Les capacités maîtrisées coûtent 1 PP de plus pendant un style.
#
# Maîtrise : une capacité apprise par niveau est maîtrisée 9, 10 ou 11 niveaux plus tard (selon le niveau
# d'apprentissage : moins de 25, moins de 35, 35 et plus). La Graine Maîtrise (seed_of_mastery) fait maîtriser une
# autre capacité (pas une capacité apprise par niveau tant que le Pokémon n'est pas au niveau max, comme dans PLA).
# Les Pokémon des dresseurs maîtrisent leurs capacités selon la même règle ; un Pokémon sauvage sur 10 maîtrise une de
# ses capacités.
#
# Réglages : Data/configs/plugins/styles_pla.json
#   settings     enabled, turns (durée du style), cooldown (attente du dresseur), extra_pp, pla_mastery (la graine ne
#                marche pas sur les capacités apprises par niveau), wild_chance (%), trainer_mastery, disable_switch
#                (n° d'interrupteur qui bloque les styles, 0 : aucun), show_info (cadre des effets), ai
#   cant_master  capacités qui ne peuvent pas être maîtrisées (Demi-Tour, Poudre Fureur…)
# Commandes d'évènement : maitriser_capacite(index, :flamethrower), capacite_maitrisee?(index, :flamethrower),
#   oublier_maitrise(index, :flamethrower)
module Configs
  class StylesPLAConfig
    attr_accessor :settings, :cant_master

    def initialize
      @settings = {}
      @cant_master = []
    end
  end
  register(:styles_pla, 'plugins/styles_pla', :json, false, StylesPLAConfig)
end

module StylesPLA
  CONFIG_FILE = 'Data/configs/plugins/styles_pla.json'
  DIR = 'styles_pla/'
  # Mécaniques ajoutées à l'onglet « ACTION » (ordre de défilement après celles du plugin gimmicks)
  KINDS = %i[strong agile].freeze
  DEFAULTS = {
    'enabled' => true, 'turns' => 2, 'cooldown' => 3, 'extra_pp' => 1, 'pla_mastery' => true, 'wild_chance' => 10,
    'trainer_mastery' => true, 'disable_switch' => 0, 'show_info' => true, 'ai' => true
  }.freeze
  # Priorité « normale » des attaques de PSDK (Battle::Move#priority vaut la priorité de la base + 7)
  NEUTRAL_PRIORITY = 7
  # Textes : [français, anglais]
  TEXTS = {
    strong: ['Style Puissant', 'Strong Style'],
    agile: ['Style Rapide', 'Agile Style'],
    strong_short: %w[Puissant Strong],
    agile_short: %w[Rapide Agile],
    enter: ['%s adopte le %s !', '%s entered %s!'],
    slower: ['%s risque d’agir plus lentement à cause du Style Puissant !', '%s may act slower due to its Strong Style!'],
    sooner: ['%s va agir plus vite grâce au Style Rapide !', '%s may act sooner due to its Agile Style!'],
    faded: ['Les effets du %2$s de %1$s se dissipent !', 'The effects of %1$s’s %2$s faded!'],
    again_player: ['Tu peux de nouveau utiliser les styles de combat !', 'You may use battle styles once again!'],
    again_foe: ['L’adversaire peut de nouveau utiliser les styles de combat !', 'The opponent may use battle styles once again!'],
    mastered: ['%s maîtrise désormais %s !', '%s mastered %s!'],
    seed_question: ['Quelle capacité maîtriser ?', 'Master which move?'],
    already: ['%s est déjà maîtrisée.', '%s has already been mastered.'],
    cant: ['%s ne peut pas être maîtrisée.', '%s isn’t capable of being mastered.'],
    level_only: ['%s ne peut maîtriser %s qu’en gagnant des niveaux.', '%s may only master %s through level-up.'],
    info_strong: [
      ['Capacités maîtrisées plus puissantes et précises', 'Mastered moves: more power and accuracy'],
      ['Effets secondaires et stats renforcés, soins +', 'Stronger added effects, stat changes, healing'],
      ['Agit plus tard pendant tout le style', 'Acts later while in this style'],
      ['Les capacités maîtrisées coûtent 1 PP de plus', 'Mastered moves cost 1 additional PP']
    ],
    info_agile: [
      ['Capacités maîtrisées moins puissantes', 'Mastered moves: less power'],
      ['Changements de stats et soins plus faibles', 'Weaker stat changes and healing'],
      ['Agit en premier ce tour-ci ; ne peut pas être apeuré', 'Acts first this turn; cannot flinch'],
      ['Les capacités maîtrisées coûtent 1 PP de plus', 'Mastered moves cost 1 additional PP']
    ]
  }.freeze

  module_function

  # @return [Configs::StylesPLAConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.styles_pla
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::StylesPLAConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::StylesPLAConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Styles de combat : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::StylesPLAConfig.new
    end
  end

  def reload
    @config = nil
    @cant_master = nil
  end

  def setting(key)
    settings = config.settings
    value = settings.is_a?(Hash) ? (settings[key.to_s].nil? ? settings[key.to_sym] : settings[key.to_s]) : nil
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def french?
    return !$options || $options.language.to_s == 'fr'
  end

  # @param key [Symbol]
  # @param args [Array] valeurs des %s
  # @return [String]
  def text(key, *args)
    pair = TEXTS[key]
    string = pair[french? ? 0 : 1]
    return args.empty? ? string : format(string, *args)
  end

  def file(name)
    return DIR + name
  end

  # @return [Boolean] les styles peuvent servir (réglage et interrupteur)
  def enabled?
    return false unless setting('enabled')

    switch = setting('disable_switch').to_i
    return !(switch > 0 && $game_switches && $game_switches[switch])
  end

  # --- Maîtrise ------------------------------------------------------------------------------------
  # @return [Array<Symbol>]
  def cant_master_list
    return @cant_master ||= Array(config.cant_master).map { |move| move.to_s.to_sym }
  end

  # @param db_symbol [Symbol]
  # @return [Boolean] la capacité peut être maîtrisée
  def masterable?(db_symbol)
    move = data_move(db_symbol)
    return false if move.db_symbol == :__undef__

    return !cant_master_list.include?(move.db_symbol)
  rescue StandardError
    return false
  end

  # Niveau auquel une capacité apprise par niveau est maîtrisée
  # @param learn_level [Integer]
  # @return [Integer]
  def mastery_level(learn_level)
    bonus = learn_level >= 35 ? 11 : (learn_level >= 25 ? 10 : 9)
    max = (PFM.game_state.level_max_limit rescue 100).to_i
    return [learn_level + bonus, max.clamp(1, 9999)].min
  end

  # Message (carte, sac, combat)
  # @param message [String]
  def announce(message)
    scene = $scene
    if scene.respond_to?(:display_message_and_wait)
      scene.display_message_and_wait(message)
    elsif scene.respond_to?(:display_message)
      scene.display_message(message)
    end
  rescue StandardError => e
    log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
  end

  # Raison pour laquelle la Graine Maîtrise ne marche pas (nil : elle marche)
  # @param pokemon [PFM::Pokemon]
  # @param skill [PFM::Skill]
  # @return [String, nil]
  def seed_refusal(pokemon, skill)
    return text(:cant, skill.name) unless pokemon && skill
    return text(:already, skill.name) if pokemon.pj_mastered?(skill.db_symbol)
    return text(:cant, skill.name) if !masterable?(skill.db_symbol) || !enabled?
    return nil unless setting('pla_mastery')

    max = (PFM.game_state.level_max_limit rescue 100).to_i
    return nil if pokemon.level >= max
    return text(:level_only, pokemon.given_name, skill.name) if pokemon.pj_level_learn(skill.db_symbol)

    return nil
  end
end

module PFM
  class Pokemon
    # @return [Array<Symbol>] capacités maîtrisées (gardées si le Pokémon les oublie puis les réapprend)
    def pj_mastered_moves
      return @pj_mastered_moves ||= []
    end

    # @param db_symbol [Symbol]
    def pj_mastered?(db_symbol)
      return pj_mastered_moves.include?(db_symbol.to_sym)
    end

    # @param db_symbol [Symbol]
    # @return [Boolean] nouvelle maîtrise
    def pj_master_move(db_symbol)
      symbol = data_move(db_symbol).db_symbol
      return false if pj_mastered?(symbol)

      pj_mastered_moves << symbol
      return true
    end

    # @param db_symbol [Symbol]
    def pj_forget_mastery(db_symbol)
      pj_mastered_moves.delete(data_move(db_symbol).db_symbol)
    end

    # @param db_symbol [Symbol]
    # @return [Integer, nil] premier niveau où l'espèce apprend la capacité
    def pj_level_learn(db_symbol)
      levels = data.move_set.select { |move| move.level_learnable? && move.move == db_symbol }.map(&:level)
      return levels.min
    rescue StandardError
      return nil
    end

    # @param db_symbol [Symbol]
    # @return [Boolean] la capacité est maîtrisée selon le niveau (sans la retenir)
    def pj_level_mastery?(db_symbol)
      learn = pj_level_learn(db_symbol)
      return learn ? level >= StylesPLA.mastery_level(learn) : false
    end

    # Maîtrise les capacités connues assez anciennes
    # @return [Array<PFM::Skill>] capacités maîtrisées à l'instant
    def pj_update_mastery
      return [] if egg? || !StylesPLA.enabled?

      return skills_set.compact.select do |skill|
        next false if pj_mastered?(skill.db_symbol) || !StylesPLA.masterable?(skill.db_symbol)
        next false unless pj_level_mastery?(skill.db_symbol)

        pj_master_move(skill.db_symbol)
      end
    end

    # Maîtrise annoncée en gagnant un niveau (Super Bonbon, évolution…)
    module StylesPLAMastery
      def check_skill_and_learn(silent = false, level = @level)
        super
        return if level.to_i <= 0 || !$actors&.include?(self)

        news = pj_update_mastery
        news.each { |skill| StylesPLA.announce(StylesPLA.text(:mastered, given_name, skill.name)) } unless silent
      rescue StandardError => e
        log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend StylesPLAMastery
  end

  # Un Pokémon sauvage sur 10 maîtrise une de ses capacités
  class Wild_Battle
    module StylesPLAWild
      def configure_battle(enemy_arr, battle_id)
        pj_wild_mastery(enemy_arr)
        return super
      end

      private

      def pj_wild_mastery(enemy_arr)
        return unless enemy_arr.is_a?(Array) && StylesPLA.enabled?

        chance = StylesPLA.setting('wild_chance').to_i
        enemy_arr.each do |pokemon|
          next unless pokemon.is_a?(PFM::Pokemon) && rand(100) < chance

          skills = pokemon.skills_set.compact.select { |skill| StylesPLA.masterable?(skill.db_symbol) }
          pokemon.pj_master_move(skills.sample.db_symbol) unless skills.empty?
        end
      rescue StandardError => e
        log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend StylesPLAWild
  end
end

# Graine Maîtrise : choisir le Pokémon puis la capacité
PFM::ItemDescriptor.define_on_creature_usability(:seed_of_mastery) do |_item, creature|
  next !creature.egg? && creature.skills_set.compact.any?
end
PFM::ItemDescriptor.define_on_move_usability(:seed_of_mastery) do |_item, skill, scene|
  pokemon = scene.instance_variable_get(:@pokemon)
  next StylesPLA.seed_refusal(pokemon, skill).nil?
end
PFM::ItemDescriptor.define_on_move_use(:seed_of_mastery) do |_item, creature, skill, scene|
  creature.pj_master_move(skill.db_symbol)
  message = StylesPLA.text(:mastered, creature.given_name, skill.name)
  scene.respond_to?(:display_message_and_wait) ? scene.display_message_and_wait(message) : scene.display_message(message)
end

module GamePlay
  class Summary
    module StylesPLASeed
      private

      def pj_seed_item?
        item = @extend_data&.item
        return item && item.db_symbol == :seed_of_mastery
      rescue StandardError
        return false
      end

      def init_win_text
        return super unless @mode == :skill && pj_seed_item?

        @base_ui.show_win_text(StylesPLA.text(:seed_question))
      end

      # La raison du refus remplace « Cela n'aura aucun effet. »
      def update_inputs_skills_validation
        if pj_seed_item? && (skill = @pokemon.skills_set[@uis[@index].index]) &&
           (why = StylesPLA.seed_refusal(@pokemon, skill))
          return display_message(why)
        end

        super
      end
    end
    prepend StylesPLASeed
  end
end

class Interpreter
  # @param index [Integer] place dans l'équipe
  # @param move [Symbol] capacité (db_symbol)
  def maitriser_capacite(index, move)
    return $actors[index]&.pj_master_move(move) ? true : false
  end

  def capacite_maitrisee?(index, move)
    return $actors[index]&.pj_mastered?(data_move(move).db_symbol) ? true : false
  end

  def oublier_maitrise(index, move)
    $actors[index]&.pj_forget_mastery(move)
  end
end
