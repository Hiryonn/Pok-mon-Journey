# Gimmicks : règles communes (une mécanique par Pokémon, une fois par combat et par dresseur)
module Gimmicks
  # Mécaniques branchées (méga, Z, Dynamax, Téra) : kind => objet qui répond à
  #   possible?(battler, logic) : le Pokémon peut l'utiliser (objet tenu, attaque…, sans compter les règles communes)
  #   execute(scene, battler, action) : transformation (cinématique comprise)
  HANDLERS = {}

  module_function

  # @param kind [Symbol]
  # @param handler [Object]
  def register(kind, handler)
    HANDLERS[kind] = handler
  end

  # @param battler [PFM::PokemonBattler]
  # @param kind [Symbol]
  # @return [Boolean] le dresseur du Pokémon a l'objet clé de la mécanique
  def key_item?(battler, kind)
    return wild_allowed?(kind) if wild?(battler)

    bag = battler.bag
    return false unless bag

    return (KEY_ITEMS[kind] || []).any? { |item| bag.contain_item?(item) }
  end

  # @param battler [PFM::PokemonBattler]
  # @return [Boolean] Pokémon sauvage
  def wild?(battler)
    return battler.bank != 0 && $scene.is_a?(Battle::Scene) && !$scene.battle_info.trainer_battle?
  rescue StandardError
    return false
  end

  # @param kind [Symbol]
  # @return [Boolean] le prochain Pokémon sauvage peut utiliser la mécanique (commande d'évènement)
  def wild_allowed?(kind)
    return (save_data[:wild] || []).include?(kind)
  end

  # État d'un combat : mécaniques déjà utilisées par chaque dresseur
  class State
    # @param logic [Battle::Logic]
    def initialize(logic)
      @logic = logic
      @used = Hash.new { |hash, kind| hash[kind] = [] }
    end

    # @param kind [Symbol]
    # @param battler [PFM::PokemonBattler]
    # @return [Boolean] le dresseur a déjà utilisé cette mécanique
    def used?(kind, battler)
      return @used[kind].any? { |owner| owner.equal?(owner_of(battler)) }
    end

    # Retient l'utilisation et bloque les autres mécaniques pour ce Pokémon
    # @param kind [Symbol]
    # @param battler [PFM::PokemonBattler]
    def mark(kind, battler)
      @used[kind] << owner_of(battler) unless used?(kind, battler)
      battler.pj_gimmick = kind
    end

    # Mécaniques possibles pour un Pokémon (ordre de Gimmicks::KINDS)
    # @param battler [PFM::PokemonBattler]
    # @param chosen [Array<Symbol>] mécaniques déjà choisies ce tour par le même dresseur
    # @return [Array<Symbol>]
    def available(battler, chosen = [])
      return [] if !battler || battler.pj_gimmick || battler.mega_evolved?

      return KINDS.select do |kind|
        next false if chosen.include?(kind)

        available?(kind, battler)
      end
    end

    # @param kind [Symbol]
    # @param battler [PFM::PokemonBattler]
    # @return [Boolean]
    def available?(kind, battler)
      return false unless (handler = HANDLERS[kind]) && Gimmicks.enabled?(kind)
      return false if battler.pj_gimmick || battler.mega_evolved? || used?(kind, battler)
      return false unless kind == :mega || Gimmicks.key_item?(battler, kind)

      return handler.possible?(battler, @logic) ? true : false
    rescue StandardError => e
      log_error("Gimmicks : #{kind} #{e.message}") if respond_to?(:log_error, true)
      return false
    end

    private

    # Le sac identifie le dresseur (comme la Méga-Évolution de PSDK) ; Pokémon sauvages : leur camp
    # @param battler [PFM::PokemonBattler]
    def owner_of(battler)
      return battler.bag || "bank#{battler.bank}"
    end
  end
end

module PFM
  class PokemonBattler
    # @return [Symbol, nil] mécanique utilisée pendant ce combat (:mega, :zmove, :dynamax, :tera)
    attr_accessor :pj_gimmick

    module PJGimmicksEnd
      # Fin du combat : le Pokémon reprend sa forme et ses PV normaux avant d'être recopié dans l'équipe
      def copy_properties_back_to_original
        pj_end_dynamax if respond_to?(:pj_end_dynamax)
        pj_end_tera if respond_to?(:pj_end_tera)
        pj_end_ultra if respond_to?(:pj_end_ultra)
        super
      end
    end
    prepend PJGimmicksEnd
  end
end

module Battle
  class Logic
    # @return [Gimmicks::State]
    def pj_gimmicks
      return @pj_gimmicks ||= Gimmicks::State.new(self)
    end

    # Méga-Évolution de PSDK + règles communes
    class MegaEvolve
      module PJGimmicks
        def can_pokemon_mega_evolve?(pokemon)
          return false unless Gimmicks.enabled?(:mega)
          return false if pokemon.pj_gimmick
          # Pokémon sauvage autorisé par commande d'évènement : pas besoin de sac
          if Gimmicks.wild?(pokemon)
            return false unless Gimmicks.wild_allowed?(:mega)

            return !@scene.logic.pj_gimmicks.used?(:mega, pokemon) && pokemon.can_mega_evolve? ? true : false
          end

          return super
        end

        def mark_as_mega_evolved(pokemon)
          super
          @scene.logic.pj_gimmicks.mark(:mega, pokemon)
        end

        private

        # Seules les vraies Méga-Évolutions du joueur comptent (pas les autres mécaniques)
        def any_mega_player_action?
          return @scene.player_actions.any? { |actions| actions.is_a?(Array) && actions.any? { |a| a.instance_of?(Actions::Mega) } }
        end
      end
      prepend PJGimmicks
    end
  end

  module Actions
    # Mécanique (Z, Dynamax, Téra) : passe avant les attaques, comme la Méga-Évolution
    class PJGimmick < Mega
      # @return [Symbol]
      attr_reader :kind
      # @return [Actions::Attack, nil] attaque choisie avec la mécanique
      attr_reader :attack

      # @param scene [Battle::Scene]
      # @param user [PFM::PokemonBattler]
      # @param kind [Symbol]
      # @param attack [Actions::Attack, nil]
      def initialize(scene, user, kind, attack = nil)
        super(scene, user)
        @kind = kind
        @attack = attack
      end

      def execute
        return if @user.dead? || @user.position.to_i < 0 || !@scene.logic.battler(@user.bank, @user.position).equal?(@user)

        handler = Gimmicks::HANDLERS[@kind]
        return unless handler

        @scene.logic.pj_gimmicks.mark(@kind, @user)
        handler.execute(@scene, @user, self)
      end

      def to_s
        return "#<PJGimmick #{@kind} #{@user}>"
      end
    end
  end

  class Scene
    module PJGimmicks
      # Le choix de la mécanique (onglet ACTION) accompagne l'attaque
      def target_choice
        kind = @visual.pj_skill_gimmick
        return super if kind.nil? || kind == :mega

        size = @player_actions.size
        super
        return if @player_actions.size <= size

        action = @player_actions.pop
        action = action.first if action.is_a?(Array)
        @player_actions << [action, Actions::PJGimmick.new(self, action.launcher, kind, action)]
      end

      def battle_end
        super
        Gimmicks.save_data[:wild] = []
      end
    end
    prepend PJGimmicks

    # @return [Array<Symbol>] mécaniques déjà choisies ce tour par le joueur
    def pj_chosen_gimmicks
      return @player_actions.select { |actions| actions.is_a?(Array) }.flat_map do |actions|
        actions.map { |a| a.is_a?(Actions::PJGimmick) ? a.kind : (a.instance_of?(Actions::Mega) ? :mega : nil) }
      end.compact
    end
  end

  class Visual
    # @return [Symbol, nil] mécanique choisie dans l'écran des attaques
    def pj_skill_gimmick
      return @skill_choice_ui&.pj_gimmick
    end
  end

  module AI
    class Base
      module PJGimmicks
        def trigger
          @pj_chosen = []
          return super
        end

        private

        def battle_action_for(pokemon)
          result = super
          return result if result.is_a?(Array) || !Gimmicks.ai_enabled?
          return result unless result.is_a?(Actions::Attack)

          kinds = @scene.logic.pj_gimmicks.available(pokemon, @pj_chosen || [])
          kinds -= [:mega] if @can_mega_evolve # PSDK a déjà décidé pour la Méga-Évolution
          kinds.select! { |kind| Gimmicks.move_selectable?(kind, pokemon, result.move) }
          return result if kinds.empty?

          last = party.count(&:alive?) <= 1
          return result unless last || Gimmicks.wild?(pokemon) || @scene.logic.generic_rng.rand < Gimmicks.ai_chance

          kind = kinds.sample(random: @scene.logic.generic_rng)
          (@pj_chosen ||= []) << kind
          action = kind == :mega ? Actions::Mega.new(@scene, pokemon) : Actions::PJGimmick.new(@scene, pokemon, kind, result)
          return [action, result]
        end
      end
      prepend PJGimmicks
    end
  end
end
