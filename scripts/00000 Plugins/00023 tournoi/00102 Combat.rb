# Tournoi : match contre un dresseur de Studio, avec écran de sélection d'équipe
module Tournoi
  # Un match : l'équipe adverse est créée tout de suite (celle que montre l'écran de sélection est celle du combat)
  class Match
    # @return [Battle::Logic::BattleInfo]
    attr_reader :info
    # @return [Hash] règles
    attr_reader :rules
    # @return [Integer, Symbol] dresseur de Studio
    attr_reader :trainer
    # @return [Integer, nil] résultat du combat (0 : gagné, 1 : fuite, 2 : perdu, 3 : abandon)
    attr_accessor :result
    # @return [Array<PFM::Pokemon>] Pokémon choisis par le joueur
    attr_reader :team

    # @param trainer [Integer, Symbol, String]
    # @param rules [Hash]
    def initialize(trainer, rules)
      @trainer = Tournoi.trainer_ref(trainer)
      @rules = rules
      @info = ::Battle::Logic::BattleInfo.new
      ::Battle::Logic::BattleInfo.add_trainer(@info, 1, @trainer)
      @team = []
    end

    # Équipe complète de l'adversaire
    # @return [Array<PFM::Pokemon>]
    def opponent_party
      return @info.parties[1]&.first || []
    end

    def opponent_name
      return Array(@info.names[1]).compact.join(' & ')
    end

    # Écran de sélection
    # @param scene [GamePlay::Base] scène qui appelle (carte ou tableau du tournoi)
    # @param party [Array<PFM::Pokemon>]
    # @return [Array<PFM::Pokemon>, nil]
    def select_team(scene, party = $actors)
      choice = nil
      scene.call_scene(SelectionScene, party, { name: opponent_name, party: opponent_party }, @rules) { |s| choice = s.choice }
      @team = choice || []
      return choice
    end

    # Pokémon de l'adversaire (au hasard, les premiers ou les plus forts)
    def pick_opponent_team
      party = opponent_party.reject(&:dead?)
      count = [@rules['pick'].to_i, party.size].min
      chosen = case @rules['opponent_pick']
               when 'first' then party.first(count)
               when 'strongest' then party.sort_by { |pokemon| -pokemon.level }.first(count)
               else party.sample(count)
               end
      opponent_party.replace(chosen) unless chosen.empty?
    end

    # Prépare le combat (après la sélection)
    def prepare
      pick_opponent_team
      _party, name, klass, battler, bag = @info.player_basic_info
      bag = PFM::Bag.new unless @rules['bag']
      @info.add_party(0, @team, name, klass, battler, bag)
      vs = [@rules['mode'].to_i, @team.size, opponent_party.size].min.clamp(1, 2)
      vs = 2 if @info.trainer_is_couple
      @info.vs_type = vs
      @info.max_level = @rules['max_level'] if @rules['max_level'].to_i > 0
      @info.background_name = @rules['background'].to_s unless @rules['background'].to_s.empty?
      @info.battle_bgm = @rules['battle_bgm'].to_s unless @rules['battle_bgm'].to_s.empty?
      @info.pj_tournoi = self
    end

    # Lance le combat
    # @param scene [GamePlay::Base, Scene_Map]
    # @param after [Proc, nil] appelé avec le résultat
    def start(scene, &after)
      prepare
      @after = after
      $game_temp.battle_can_lose = true
      @no_exp_before = $game_switches[Yuki::Sw::BT_NoExp]
      $game_switches[Yuki::Sw::BT_NoExp] = true unless @rules['exp']
      if scene.is_a?(::Scene_Map)
        @from_map = true
        Graphics.freeze
        $scene = ::Battle::Scene.new(@info)
        Yuki::FollowMe.set_battle_entry
      else
        scene.call_scene(::Battle::Scene, @info)
      end
    end

    # @return [Boolean] le combat est lancé depuis la carte (le retour à la carte est normal)
    def from_map?
      return @from_map == true
    end

    # Fin du combat (appelé par la scène de combat)
    def finish(result)
      @result = result
      $game_switches[Yuki::Sw::BT_NoExp] = @no_exp_before
      @after&.call(result)
    end

    def won?
      return @result == 0
    end
  end

  module_function

  # Combat contre un dresseur avec écran de sélection (depuis la carte)
  # @param trainer [Integer, Symbol]
  # @param rules [Hash]
  # @return [Boolean, nil] nil : sélection abandonnée
  def selection_battle(trainer, rules)
    unless trainer_exists?(trainer)
      log_error("Tournoi : dresseur inconnu #{trainer}") if respond_to?(:log_error, true)
      return nil
    end
    match = Match.new(trainer, rules)
    team = match.select_team($scene)
    return nil if team.nil? || team.empty?

    bgm = $game_system.playing_bgm
    match.start($scene) do |result|
      @last_selection = result
      Tournoi.heal(team) if rules['heal']
      $game_system.bgm_play(bgm) if bgm && !match.from_map?
    end
    return true
  end

  # @return [Integer, nil] résultat du dernier combat avec sélection
  def last_selection
    return @last_selection
  end

  # --- Sélection seule : l'équipe est réduite jusqu'à la fin du prochain combat (comme dans le plugin d'origine) -------
  # @param trainer [Integer, Symbol]
  # @param rules [Hash]
  # @return [Boolean] l'équipe a été choisie
  def select_only(trainer, rules)
    return false unless trainer_exists?(trainer)

    match = Match.new(trainer, rules)
    team = match.select_team($scene)
    return false if team.nil? || team.empty?

    PFM.game_state.instance_variable_set(:@pj_tournoi_party, $actors.dup)
    $actors.replace(team)
    return true
  end

  # Remet l'équipe complète (après le combat qui suit une sélection seule)
  def restore_party
    state = PFM.game_state
    full = state.instance_variable_get(:@pj_tournoi_party)
    return unless full

    state.remove_instance_variable(:@pj_tournoi_party)
    extra = $actors.reject { |pokemon| full.any? { |p| p.equal?(pokemon) } }
    $actors.replace((full + extra).first(6))
  end
end

module Battle
  class Logic
    class BattleInfo
      # @return [Tournoi::Match, nil]
      attr_accessor :pj_tournoi
    end
  end

  class Scene
    module TournoiScene
      def battle_end
        match = @battle_info.respond_to?(:pj_tournoi) ? @battle_info.pj_tournoi : nil
        if match && !@pj_tournoi_ended
          @pj_tournoi_ended = true
          match.result = @logic.battle_result
        end
        super
        match&.finish(@logic.battle_result)
        Tournoi.restore_party if !match && PFM.game_state.instance_variable_defined?(:@pj_tournoi_party)
      end

      private

      # Tournoi : le combat rend la main au tableau
      def return_to_last_scene
        match = @battle_info.respond_to?(:pj_tournoi) ? @battle_info.pj_tournoi : nil
        return super unless match && !match.from_map?

        @running = false
      end
    end
    prepend TournoiScene
  end
end
