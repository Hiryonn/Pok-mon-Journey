# encoding: utf-8
# Combats spéciaux : lancement des combats triples et des hordes
module Battle
  class Logic
    class BattleInfo
      # @return [Hash, nil] combat spécial en cours ({ kind:, variable:, after: })
      attr_accessor :pj_special
    end
  end

  class Scene
    module CombatsSpeciauxScene
      def battle_end
        special = @battle_info.respond_to?(:pj_special) ? @battle_info.pj_special : nil
        result = @logic.battle_result if special
        super
        CombatsSpeciaux.finish(special, result) if special
      end
    end
    prepend CombatsSpeciauxScene
  end
end

module CombatsSpeciaux
  module_function

  # @return [Boolean, nil] résultat du dernier combat spécial (nil : aucun)
  def last_won
    return @last_won
  end

  # Pokémon du joueur en état de se battre
  # @param count [Integer]
  # @return [Array<PFM::Pokemon>]
  def team(count)
    return $actors.reject(&:dead?).first(count)
  end

  # @param count [Integer] nombre de Pokémon qu'il faut
  # @return [Boolean]
  def possible?(count = 3)
    return $actors.reject(&:dead?).size >= count
  end

  # Nombre de Pokémon en jeu pour chaque camp
  # @param wanted [Integer]
  # @param foes [Integer] Pokémon adverses disponibles
  # @return [Integer, nil] nil : le combat est refusé
  def slots(wanted, foes)
    mine = $actors.reject(&:dead?).size
    return nil if mine.zero?
    return [wanted, foes].min if mine >= wanted
    return nil unless setting('triple_fallback')

    return [mine, foes].min
  end

  # Fin du combat (appelé par la scène de combat)
  # @param special [Hash]
  # @param result [Integer] 0 : gagné
  def finish(special, result)
    @last_won = result == 0
    variable = special[:variable].to_i
    $game_variables[variable] = @last_won ? 1 : 0 if variable > 0
    special[:after]&.call(@last_won)
  rescue StandardError => e
    log_error("Combats spéciaux : fin de combat (#{e.message})") if respond_to?(:log_error, true)
  end

  # Prépare les réglages communs du combat
  def apply_common(info, kind)
    bgm = setting("#{kind}_bgm").to_s
    info.battle_bgm = bgm unless bgm.empty?
    background = setting('background').to_s
    info.background_name = background unless background.empty?
  end

  # Lance le combat
  # @param info [Battle::Logic::BattleInfo]
  def launch(info)
    $game_temp.battle_can_lose = true if $game_temp.respond_to?(:battle_can_lose=)
    if $scene.is_a?(::Scene_Map)
      Graphics.freeze
      $scene = ::Battle::Scene.new(info)
      Yuki::FollowMe.set_battle_entry
    else
      $scene.call_scene(::Battle::Scene, info)
    end
  end

  # 3 contre 3 contre un dresseur de Studio
  # @param trainer [Integer, Symbol, String]
  # @return [Boolean] le combat a été lancé
  def triple_battle(trainer, variable: 0, &after)
    ref = trainer_ref(trainer)
    unless ref && trainer_exists?(ref)
      log_error("Combats spéciaux : dresseur inconnu #{trainer.inspect}") if respond_to?(:log_error, true)
      return false
    end
    info = ::Battle::Logic::BattleInfo.new
    ::Battle::Logic::BattleInfo.add_trainer(info, 1, ref)
    foes = info.parties[1]&.first || []
    size = slots(3, foes.reject(&:dead?).size)
    return refuse if size.nil? || size.zero?

    start_info(info, :triple, size, variable, after)
  end

  # Pokémon sauvages en même temps (3 au plus)
  # @param specs [Array<Array>] [[espèce, niveau], ...]
  def wild_trio(specs, variable: 0, &after)
    wild = Array(specs).first(3).map { |species, level| make_wild(species, level) }.compact
    return false if wild.empty?

    info = ::Battle::Logic::BattleInfo.new
    size = slots(3, wild.size)
    return refuse if size.nil? || size.zero?

    info.add_party(1, wild)
    start_info(info, :triple, size, variable, after)
  end

  # Horde : la même espèce plusieurs fois ; horde_active Pokémon en jeu, les autres entrent à la place des K.O.
  def horde(species, level, size: nil, form: 0, variable: 0, &after)
    count = (size || setting('horde_size')).to_i.clamp(2, 5)
    spread = setting('horde_spread').to_i
    wild = Array.new(count) do
      lvl = level.to_i + (spread > 0 ? rand(-spread..spread) : 0)
      make_wild(species, [lvl, 1].max, form)
    end.compact
    return false if wild.empty?

    # Horde « 1 ou 2 contre 5 » : vs_type est commun aux deux camps, donc on le règle sur le plus grand camp (les sauvages)
    # et le joueur n'envoie que horde_player Pokémon (comme le boss seul d'un raid, avec moins de Pokémon que de positions)
    active = setting('horde_active').to_i.clamp(1, 5)
    active = [active, wild.size].min
    mine = [setting('horde_player').to_i.clamp(1, 2), $actors.reject(&:dead?).size].min
    return refuse if mine.zero?

    info = ::Battle::Logic::BattleInfo.new
    info.add_party(1, wild)
    _party, name, klass, battler, bag = info.player_basic_info
    info.add_party(0, team(mine), name, klass, battler, bag)
    info.vs_type = [active, mine].max
    info.pj_special = { kind: :horde, variable: variable, after: after }
    apply_common(info, 'horde')
    launch(info)
    return true
  end

  def start_info(info, kind, size, variable, after)
    _party, name, klass, battler, bag = info.player_basic_info
    info.add_party(0, team(size), name, klass, battler, bag)
    info.vs_type = size
    info.pj_special = { kind: kind, variable: variable, after: after }
    apply_common(info, kind == :horde ? 'horde' : 'triple')
    launch(info)
    return true
  end

  def refuse
    $scene.display_message_and_wait(t('Il faut des Pokémon en état de se battre !', 'You need Pokémon that can fight!')) if $scene.respond_to?(:display_message_and_wait)
    return false
  end

  def make_wild(species, level, form = 0)
    return PFM::Pokemon.new(species.is_a?(Integer) ? species : species.to_sym, level.to_i.clamp(1, 100), false, false, form.to_i)
  rescue StandardError => e
    log_error("Combats spéciaux : espèce inconnue #{species.inspect} (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  def trainer_ref(value)
    return nil if value.nil? || value.to_s.empty?
    return value if value.is_a?(Integer)
    return value.to_i if value.to_s.match?(/\A\d+\z/)

    return value.to_s.to_sym
  end

  def trainer_exists?(ref)
    return data_trainer(ref).db_symbol != :__undef__
  rescue StandardError
    return false
  end
end
