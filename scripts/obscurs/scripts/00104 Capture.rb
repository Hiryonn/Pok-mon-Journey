# Pokémon Obscurs : Pokémon Obscurs des dresseurs et capture (« snag »)
#
# Les dresseurs réglés dans Studio reçoivent leurs Pokémon Obscurs au début du combat (sauf s'ils ont déjà été
# capturés). Dans un combat de dresseur, une Ball peut capturer un Pokémon Obscur si le joueur a le Snatcheur
# (réglage snag_machine) ou si c'est la Snatch Ball (réglage snag_ball) ; les autres Pokémon restent intouchables.
# Après la capture, le combat continue : le dresseur envoie son Pokémon suivant (ou perd s'il n'en a plus).
module Obscurs
  module_function

  # @param ball [Studio::BallItem]
  # @return [Boolean] la Ball peut capturer un Pokémon Obscur d'un dresseur
  def snag_ball?(ball)
    machine = setting('snag_machine').to_s
    return true if !machine.empty? && $bag.contain_item?(machine.to_sym)

    snag = setting('snag_ball').to_s
    return !snag.empty? && ball.db_symbol.to_s == snag
  rescue StandardError
    return false
  end

  # Applique les Pokémon Obscurs réglés pour ce dresseur
  # @param trainer_symbol [Symbol]
  # @param party [Array<PFM::Pokemon>]
  def apply_trainer(trainer_symbol, party)
    trainer_entries.each do |entry|
      next unless fetch(entry, 'trainer').to_s == trainer_symbol.to_s

      pokemon = party[fetch(entry, 'slot').to_i]
      next if pokemon.nil? || pokemon.shadow?

      id = fetch(entry, 'id').to_s
      id = "#{trainer_symbol}_#{fetch(entry, 'slot').to_i}" if id.empty?
      next if %w[snagged purified].include?(status(id))

      make_shadow(pokemon, id: id, gauge: fetch(entry, 'gauge'), moves: fetch(entry, 'moves'))
    end
  end
end

module Battle
  class Logic
    class BattleInfo
      class << self
        module ObscursTrainers
          def add_trainer(battle_info, bank, id_trainer)
            super
            party = battle_info.parties[bank]&.last
            trainer = data_trainer(id_trainer)
            Obscurs.apply_trainer(trainer.db_symbol, party) if party && trainer
          rescue StandardError => e
            log_error("Obscurs : #{e.message}") if respond_to?(:log_error, true)
          end
        end
        prepend ObscursTrainers
      end
    end

    class CatchHandler
      module ObscursSnag
        private

        def ball_blocked_for_trainer_battle?(target, ball)
          return super unless @scene.logic.battle_info.trainer_battle? && target.shadow?
          return false if Obscurs.snag_ball?(ball)

          @scene.visual.show_catch_blocked_animation(target, ball)
          $bag.add_item(ball.db_symbol)
          @scene.display_message_and_wait(Obscurs.t('Il faut un Snatcheur pour capturer le Pokémon Obscur d’un Dresseur !',
                                                    "You need a Snag Machine to snag a Trainer's Shadow Pokémon!"))
          return true
        end
      end
      prepend ObscursSnag
    end
  end

  class Scene
    module ObscursSnag
      private

      # Capture d'un Pokémon Obscur de dresseur : le combat continue
      def caught(item_wrapper)
        return super unless @logic.battle_info.trainer_battle? && !is_a?(Battle::Safari)

        target = catch_target
        ball = item_wrapper.item
        if logic.catch_handler.try_to_catch_pokemon(target, logic.alive_battlers(0).first, ball)
          snag_pokemon(target, ball)
          @next_update = @logic.can_battle_continue? ? :trigger_all_AI : :battle_end
        else
          @next_update = :trigger_all_AI
        end
        should_activate_ball_fetch?(item_wrapper)
      end

      # @param target [PFM::PokemonBattler]
      # @param ball [Studio::BallItem]
      def snag_pokemon(target, ball)
        pkmn = target.original
        trainer = @battle_info.names.dig(target.bank, target.party_id)
        message_window.blocking = true
        message_window.wait_input = true
        $game_system.me_play(Configs.sounds.catch_creature_me)
        pkmn.captured_with = target.captured_with = ball.id
        target.instance_variable_set(:@pj_snagged, true)
        target.copy_properties_back_to_original
        pkmn.hp = target.hp
        display_message_and_wait(Obscurs.t("#{pkmn.given_name} a été capturé !", "#{pkmn.given_name} was snagged!"))
        Obscurs.record(pkmn, 'snagged', trainer)
        update_pokemon_related_quests(pkmn)
        update_pokedex_related_infos(pkmn)
        rename_sequence(pkmn) if $options.catch_rename
        @visual.show_exp_distribution(@logic.exp_handler.distribute_exp_for(target))
        $game_system.map_interpreter.add_pokemon(pkmn)
        if $game_switches[Yuki::Sw::SYS_Stored]
          display_message_and_wait(parse_text(30, 1, PKNICK[0] => pkmn.given_name, '[VAR BOX(0001)]' => $storage.get_box_name($storage.current_box)))
        end
        # le combattant ne renvoie plus rien vers le Pokémon capturé
        target.instance_variable_set(:@original, pkmn.clone)
        target.instance_variable_set(:@hp, 0)
        @visual.hide_info_bar(target)
        %i[@sprite @ball @burst_catch @burst2].each do |ivar|
          sprite = @visual.instance_variable_get(ivar)
          sprite.dispose if sprite.respond_to?(:dispose) && !(sprite.respond_to?(:disposed?) && sprite.disposed?)
        end
        @visual.battler_sprite(target.bank, target.position)&.visible = false
      end
    end
    prepend ObscursSnag

    module ObscursWildCatch
      private

      # Pokémon Obscur sauvage capturé : noté dans le registre
      def give_pokemon_procedure(battler, ball)
        Obscurs.record(battler.original, 'snagged') if battler.shadow?
        super
      end
    end
    prepend ObscursWildCatch
  end
end
