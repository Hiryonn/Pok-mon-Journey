# Pokémon Obscurs : combat (annonce, aura, furie, Appel, expérience gardée, jauge après le combat)
#
# Furie (Pokémon Obscurs du joueur seulement) : à la fin d'un tour, chance d'entrer en furie selon les barres de la
# jauge (réglage fury_chance).
#   mode Hyper (XD)        : le Pokémon n'écoute pas toujours les ordres (hyper_disobey %) : il lance une autre
#                            capacité au hasard ou ne fait rien ; ses coups critiques sont plus fréquents.
#   mode Inversion (Colo.) : il perd 1 / reverse_damage de ses PV à chaque fin de tour et sa jauge remonte.
# Appel : remplace « Fuite » quand le Pokémon actif est Obscur (combat de dresseur) ou en furie ; il apaise la furie
# (la jauge baisse de call_gauge), sinon il réveille le Pokémon ou le concentre (Précision +1).
module Obscurs
  module_function

  # Le Pokémon peut entrer en furie (joueur, Obscur, jauge pas trop basse)
  def fury_possible?(battler)
    return false unless battler.shadow? && battler.from_party? && battler.alive?
    return false if battler.shadow_fury?

    chance = Array(setting('fury_chance'))[battler.heart_stage].to_i
    return chance > 0 && rand(100) < chance
  end

  def fury_name
    return t('mode Hyper', 'Hyper Mode') if hyper? && !reverse?
    return t('mode Inversion', 'Reverse Mode') if reverse? && !hyper?

    return t('furie', 'a frenzy')
  end
end

module Battle
  module Actions
    # Appel d'un Pokémon Obscur
    class ShadowCall < Base
      attr_reader :user

      # @param scene [Battle::Scene]
      # @param user [PFM::PokemonBattler]
      def initialize(scene, user)
        super(scene)
        @user = user
      end

      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem) || other.is_a?(Shift)
        return ShadowCall.from(other).user.spd <=> @user.spd if other.is_a?(ShadowCall)

        return -1
      end

      def execute
        return if @user.dead?

        scene = @scene
        player = scene.battle_info.names.dig(0, 0) || $trainer.name
        scene.display_message_and_wait(Obscurs.t("#{player} appelle #{@user.given_name} !", "#{player} called #{@user.given_name}!"))
        if @user.shadow_fury?
          @user.shadow_fury = false
          @user.change_heart_gauge(-Obscurs.setting('call_gauge').to_i)
          scene.display_message_and_wait(Obscurs.t("#{@user.given_name} est revenu à lui !", "#{@user.given_name} came to its senses!"))
        elsif @user.asleep?
          scene.logic.status_change_handler.status_change(:cure, @user)
          scene.display_message_and_wait(Obscurs.t("#{@user.given_name} s’est réveillé !", "#{@user.given_name} woke up!"))
        else
          handler = scene.logic.stat_change_handler
          handler.stat_change_with_process(:acc, 1, @user)
        end
      end
    end
  end

  class Scene
    module ObscursCall
      private

      def player_action_choice_internal(choice, forced_action)
        if choice == :flee && (battler = shadow_call_battler)
          @player_actions << Actions::ShadowCall.new(self, battler)
          return @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
        end

        super
      end

      # @return [PFM::PokemonBattler, nil] Pokémon qui peut être appelé à la place de la fuite
      def shadow_call_battler
        battler = @logic.battler(0, @player_actions.size)
        return nil unless battler&.shadow? && battler.from_party?
        return battler if battler.shadow_fury? || @logic.battle_info.trainer_battle?

        return nil
      end
      public :shadow_call_battler
    end
    prepend ObscursCall

    # Pas de choix d'action pour la furie de l'Ennemi : rien
  end

  class Visual
    module ObscursCallButton
      private

      # « Fuite » devient « Appel » pour un Pokémon Obscur
      def show_player_choice_begin(pokemon_index)
        super
        buttons = @player_choice_ui.instance_variable_get(:@buttons)
        button = buttons.is_a?(Array) ? buttons[3] : nil
        text = button&.instance_variable_get(:@text)
        return unless text.respond_to?(:text=)

        @pj_flee_text ||= text.text
        call = @scene.respond_to?(:shadow_call_battler) && @scene.logic.battler(0, pokemon_index) &&
               (battler = @scene.logic.battler(0, pokemon_index)).shadow? && battler.from_party? &&
               (battler.shadow_fury? || @scene.logic.battle_info.trainer_battle?)
        text.text = call ? Obscurs.t('Appel', 'Call') : @pj_flee_text
      end
    end
    prepend ObscursCallButton
  end

  module Actions
    class Attack
      module ObscursFury
        # Mode Hyper : le Pokémon n'écoute pas toujours les ordres
        def execute
          return super unless Obscurs.hyper? && @launcher.shadow_fury? && @launcher.from_party? && @launcher.alive?
          return super unless rand(100) < Obscurs.setting('hyper_disobey').to_i

          scene = @scene
          name = @launcher.given_name
          scene.display_message_and_wait(Obscurs.t("#{name} est en #{Obscurs.fury_name} !", "#{name} is in #{Obscurs.fury_name}!"))
          others = @launcher.moveset.select { |move| move.pp > 0 && move != @move }
          if others.empty? || rand(2) == 0
            return scene.display_message_and_wait(Obscurs.t("#{name} n’écoute pas les ordres !", "#{name} ignored orders!"))
          end

          move = others.sample
          scene.display_message_and_wait(Obscurs.t("#{name} n’en fait qu’à sa tête !", "#{name} did what it wanted!"))
          foes = scene.logic.foes_of(@launcher).select(&:alive?)
          target = foes.sample || @launcher
          move.proceed(@launcher, target.bank, target.position)
          scene.on_after_attack(@launcher, move)
        end
      end
      prepend ObscursFury
    end
  end

  class Logic
    module ObscursCritical
      # Mode Hyper : coups critiques plus fréquents
      def calc_critical_hit(user, target, critical_rate)
        critical_rate += 1 if Obscurs.hyper? && user.respond_to?(:shadow_fury?) && user.shadow_fury? && critical_rate.to_i > 0
        return super(user, target, critical_rate)
      end
    end
    prepend ObscursCritical

    class SwitchHandler
      module ObscursAnnounce
        # Annonce des Pokémon Obscurs envoyés au combat
        def execute_switch_events(who, with)
          super
          return unless with&.alive? && with.shadow?

          with.instance_variable_set(:@pj_shadow_fought, true)
          announced = @logic.instance_variable_get(:@pj_shadow_announced) || @logic.instance_variable_set(:@pj_shadow_announced, [])
          return if announced.include?(with.original)

          announced << with.original
          trainer = @logic.battle_info.trainer_battle? && with.bank == 1 ? @logic.battle_info.names.dig(1, with.party_id) : nil
          Obscurs.record(with.original, 'seen', trainer) if with.bank == 1
          @scene.display_message_and_wait(Obscurs.t("#{with.given_name} est un Pokémon Obscur !", "#{with.given_name} is a Shadow Pokémon!"))
        end
      end
      prepend ObscursAnnounce
    end

    class EndTurnHandler
      module ObscursFury
        # Fin de tour : furie (entrée, mode Inversion)
        def process_events
          super
          @logic.all_alive_battlers.each do |battler|
            next unless battler.shadow? && battler.from_party?

            if battler.shadow_fury?
              next unless Obscurs.reverse?

              @scene.display_message_and_wait(Obscurs.t("#{battler.given_name} est en #{Obscurs.fury_name} et se blesse !",
                                                        "#{battler.given_name} is in #{Obscurs.fury_name} and hurt itself!"))
              @logic.damage_handler.damage_change((battler.max_hp / Obscurs.setting('reverse_damage').to_i.clamp(1, 100)).clamp(1, battler.hp), battler)
              battler.change_heart_gauge(Obscurs.setting('reverse_gauge').to_i)
            elsif Obscurs.fury_possible?(battler)
              battler.shadow_fury = true
              Obscurs.play_se('057-wrong01', 80)
              @scene.display_message_and_wait(Obscurs.t("#{battler.given_name} est entré en #{Obscurs.fury_name} !",
                                                        "#{battler.given_name} entered #{Obscurs.fury_name}!"))
            end
          end
        end
      end
      prepend ObscursFury
    end

    class ExpHandler
      module ObscursExp
        # Un Pokémon Obscur garde l'expérience pour sa purification
        def distribute_exp_for(enemy)
          data = super
          data.each_key.select { |receiver| receiver.shadow? }.each do |receiver|
            receiver.add_shadow_exp(data.delete(receiver))
          end
          return data
        end
      end
      prepend ObscursExp
    end

    class BattleEndHandler
      module ObscursEnd
        def process
          shadow_battle_end
          super
        end

        private

        def shadow_battle_end
          @logic.all_battlers.each do |battler|
            next unless battler.shadow?

            if battler.from_party?
              battler.shadow_fury = false
              battler.change_heart_gauge(-Obscurs.setting('battle_gauge').to_i) if battler.instance_variable_get(:@pj_shadow_fought)
            elsif battler.bank == 1 && battler.dead? && !battler.instance_variable_get(:@pj_snagged)
              Obscurs.record(battler.original, 'missed')
            end
          end
        end
      end
      prepend ObscursEnd
    end
  end
end

# Aura des Pokémon Obscurs (violette, rouge en furie)
module BattleUI
  class PokemonSprite
    module ObscursAura
      def update
        super
        pokemon = @pokemon
        return unless pokemon.respond_to?(:shadow?) && pokemon.shadow? && Obscurs.setting('aura')
        return if @animation_tone && !@stop_status_tone
        return if pokemon.dead? || !visible

        @pj_aura = (@pj_aura || 0) + 1
        alpha = 0.25 + 0.2 * Math.sin(@pj_aura / 12.0)
        color = pokemon.shadow_fury? ? [0.75, 0.05, 0.2, alpha + 0.1] : [0.35, 0.05, 0.55, alpha]
        shader&.set_float_uniform('color', color)
      rescue StandardError
        nil
      end
    end
    prepend ObscursAura
  end
end
