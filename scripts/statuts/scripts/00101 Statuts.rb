# Statuts : mise en place dans PSDK (numéros, Pokémon, combat, icônes, commandes d'évènement)
module Statuts
  module_function

  # Inscrit les statuts du projet (une seule fois, au premier besoin)
  def install!
    return if @installed
    return unless defined?(Battle::Effects::Status) && defined?(UI::CustomStatusAnimation)

    @installed = true
    ids = Configs.states.instance_variable_get(:@ids)
    list.each do |d|
      ids[d.symbol] = d.number
      Battle::Effects::Status.register(d.symbol, Battle::Effects::Status::Custom)
      UI::StatusAnimation.register(d.symbol, UI::CustomStatusAnimation)
      if defined?(BattleUI::PokemonSprite)
        r, g, b = d.rgb
        BattleUI::PokemonSprite::STATUS_TONE[d.symbol] ||= [r * 0.6, g * 0.6, b * 0.6, 0.7, 0]
        BattleUI::PokemonSprite::STATUS_SE[d.symbol] ||= 'moves/poison'
      end
      Battle::Logic::CatchHandler::STATUS_MODIFIER[d.symbol] ||= d.catch_rate if defined?(Battle::Logic::CatchHandler)
    end
  rescue StandardError => e
    log_error("Statuts : installation impossible (#{e.message})") if respond_to?(:log_error, true)
  end

  # Le Pokémon peut-il recevoir ce statut ? (pas de statut, pas d'un type immunisé)
  # @param pokemon [PFM::Pokemon]
  # @param definition [Definition]
  def can_have?(pokemon, definition)
    return false if pokemon.status != 0

    return definition.immune_types.none? do |type|
      pokemon.type?(data_type(type).id)
    rescue StandardError
      false
    end
  end
end

module Configs
  class States
    # Les statuts du projet sont ajoutés aux numéros de PSDK
    module StatutsIds
      def ids
        Statuts.install!
        return super
      end

      def symbol(id)
        Statuts.install!
        return super
      end
    end
    prepend StatutsIds
  end
end

module PFM
  class Pokemon
    # Le Pokémon a-t-il ce statut du projet ?
    # @param symbol [Symbol]
    def custom_status?(symbol)
      d = Statuts.find(symbol)
      return d ? @status == d.number : false
    end

    # Donne un statut du projet
    # @param symbol [Symbol]
    # @param forcing [Boolean]
    # @return [Boolean]
    def status_custom(symbol, forcing = false)
      d = Statuts.find(symbol)
      return false unless d
      return false unless (@status == 0 || forcing) && !dead?

      @status = d.number
      return true
    end

    # @param symbol [Symbol]
    def can_be_custom_status?(symbol)
      d = Statuts.find(symbol)
      return d ? Statuts.can_have?(self, d) : false
    end

    # Saignement
    def bleeding?
      return custom_status?(:bleeding)
    end

    def status_bleeding(forcing = false)
      return status_custom(:bleeding, forcing)
    end

    def can_be_bleeding?
      return can_be_custom_status?(:bleeding)
    end
  end
end

module Battle
  module Effects
    class Status
      # Statut du projet : diviseurs de stats, dégâts à chaque tour
      class Custom < Status
        # @return [Statuts::Definition, nil]
        def definition
          return Statuts.find(@status)
        end

        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target || status != @status

          return handler.prevent_change do
            handler.scene.display_message_and_wait(definition.message(:already, target)) if definition
          end
        end

        def on_end_turn_event(logic, scene, battlers)
          d = definition
          return unless d && d.damage > 0
          return unless battlers.include?(target)
          return if target.dead? || target.has_ability?(:magic_guard)

          scene.display_message_and_wait(d.message(:damage, target))
          scene.visual.show_status_animation(target, @status)
          logic.damage_handler.damage_change((target.max_hp / d.damage).clamp(1, Float::INFINITY), target)
        end

        def atk_modifier
          return definition ? 1.0 / definition.stats[:atk] : 1
        end

        def dfe_modifier
          return definition ? 1.0 / definition.stats[:dfe] : 1
        end

        def ats_modifier
          return definition ? 1.0 / definition.stats[:ats] : 1
        end

        def dfs_modifier
          return definition ? 1.0 / definition.stats[:dfs] : 1
        end

        def spd_modifier
          return definition ? 1.0 / definition.stats[:spd] : 1
        end

        def name
          return @status
        end
      end
    end
  end

  class Logic
    class StatusChangeHandler
      # Statuts du projet : application, message, guérison
      module StatutsChange
        def status_change(status, target, launcher = nil, skill = nil, message_overwrite: nil)
          d = Statuts.find(status)
          if d
            target.status_custom(status, true)
            @scene.visual.show_status_animation(target, status)
            @scene.display_message_and_wait(d.message(:inflict, target))
            handle_post_change_events(status, target, launcher, skill)
            @scene.visual.refresh_info_bar(target)
            return
          end
          if status == :cure && (d = Statuts.find(target.status)) && message_overwrite.nil?
            target.cure
            @scene.visual.heal_status_remove_tone(target)
            @scene.display_message_and_wait(d.message(:cure, target))
            handle_post_change_events(status, target, launcher, skill)
            @scene.visual.refresh_info_bar(target)
            return
          end
          super
        end

        private

        def check_status_prevention(status, target, launcher, skill)
          d = Statuts.find(status)
          return super unless d

          result = logic.each_effects(target, launcher) do |effect|
            next(effect.on_status_prevention(self, status, target, launcher, skill))
          end
          return result if result
          return if target.can_be_custom_status?(status)

          return prevent_change do
            next unless skill.nil? || skill.status?

            scene.display_message_and_wait(d.message(:immune, target))
          end
        end
      end
      prepend StatutsChange
    end
  end

  class Move
    # Attaques qui infligent un statut du projet (Données > Statuts > attaques), en plus de leurs effets
    module StatutsMoves
      def deal_status(user, actual_targets)
        result = super
        Statuts.list.each do |d|
          chance = d.moves[db_symbol]
          next unless chance && chance > 0

          actual_targets.each do |target|
            next if target.dead? || target == user && !status?
            next unless @logic.generic_rng.rand(100) < chance

            handler = @logic.status_change_handler
            if status?
              handler.status_change_with_process(d.symbol, target, user, self)
            elsif handler.status_appliable?(d.symbol, target, user, self)
              handler.status_change(d.symbol, target, user, self)
            end
          end
        end
        return result
      end
    end
    prepend StatutsMoves
  end
end

module BattleUI
  class PokemonSprite
    # Pas d'image d'animation : seulement la teinte et le son
    module StatutsAnimation
      def status_animation(status)
        sym = status.is_a?(Integer) ? Configs.states.symbol(status) : status
        d = Statuts.find(sym)
        return super unless d && !RPG::Cache.animation_exist?("status/#{sym}")

        return if under_substitute_effect?

        set_tone_status(sym)
      end
    end
    prepend StatutsAnimation
  end
end

module UI
  # Animation d'un statut du projet : graphics/animations/status/<statut>.png (12 x 10 images, comme le poison)
  class CustomStatusAnimation < StatusAnimation
    def x_offset
      return -3
    end

    def y_offset
      return 3
    end

    def status_dimension
      return [12, 10]
    end

    def status_filename
      return "status/#{@status}"
    end

    def status_duration
      return 1.2
    end
  end

  class StatusSprite
    # Icônes : graphics/interface/statuts<langue>.png a une ligne de 10 pixels par numéro de statut
    module StatutsRows
      def initialize(viewport)
        super
        rows = bitmap ? bitmap.height / 10 : STATE_COUNT
        self.nb_y = rows if rows > STATE_COUNT
      end
    end
    prepend StatutsRows
  end
end

class Interpreter
  # Donne un statut à un Pokémon de l'équipe (commande Script)
  # @param statut [Symbol] :bleeding…
  # @param index [Integer] position dans l'équipe (0 = premier)
  # @param forcer [Boolean] remplace le statut actuel
  # @return [Boolean]
  def infliger_statut(statut, index = 0, forcer: false)
    pokemon = $actors[index]
    return false unless pokemon

    return pokemon.status_custom(statut, forcer) if Statuts.find(statut)

    method = Battle::Logic::StatusChangeHandler::STATUS_APPLY_METHODS[statut]
    return method ? pokemon.send(method, forcer) : false
  end

  # Le Pokémon de l'équipe a-t-il ce statut ?
  def a_le_statut?(statut, index = 0)
    pokemon = $actors[index]
    return false unless pokemon

    return pokemon.status == Configs.states.ids[statut]
  end
end
