# Extra Abilities Additions : outils communs. Chaque talent a son fichier (00110 et suivants) ; pour en ajouter un :
# crée le talent sous Studio (ou ajoute-le à tools/pokengine/talents_pokengine.py puis lance creer_talents_pokengine.bat),
# puis un fichier avec  ExtraAbilitiesAdditions.define(:symbole_du_talent) { ... }  ou l'un des raccourcis (boost, convert, absorb).
# Moteur : Battle::Effects::Ability (doc : psdk.pokemonworkshop.com/yard). Les erreurs d'un talent sont attrapées et écrites
# dans le journal : un effet cassé ne bloque jamais le combat.
module ExtraAbilitiesAdditions
  SUN = %i[sunny hardsun].freeze
  HAZARDS = %i[spikes toxic_spikes stealth_rock sticky_web].freeze
  SCREENS = %i[light_screen reflect aurora_veil safeguard mist].freeze
  FIELD_EFFECTS = %i[gravity trick_room magic_room wonder_room mud_sport water_sport ion_deluge].freeze
  HERBS = %i[white_herb mental_herb power_herb].freeze
  STAGES = %i[atk dfe ats dfs spd acc eva].freeze

  # Outils disponibles dans chaque talent défini ici.
  module Helpers
    def ea_safe(where, default = nil)
      return yield
    rescue StandardError => e
      ExtraAbilitiesAdditions.log_error(where, e)
      return default
    end

    def ea_type_id(symbol)
      return GameData::Type[symbol]&.id
    rescue StandardError
      return nil
    end

    def ea_type?(move, symbol)
      id = ea_type_id(symbol)
      return !id.nil? && move.type == id
    end

    def ea_low_hp?
      return @target.hp_rate <= 1.0 / 3
    end

    def ea_weather
      return ExtraAbilitiesAdditions.weather(@logic)
    end

    def ea_sun?
      return SUN.include?(ea_weather)
    end

    def ea_show(scene, pokemon)
      scene.visual.show_ability(pokemon)
    rescue StandardError
      nil
    end

    def ea_stat(logic, stat, power, target, source = nil, move = nil)
      logic.stat_change_handler.stat_change_with_process(stat, power, target, source, move)
    end

    def ea_heal(logic, pokemon, hp)
      logic.damage_handler.heal(pokemon, [hp.to_i, 1].max)
    end

    def ea_foes(logic, pokemon)
      return logic.adjacent_foes_of(pokemon)
    end

    # Bloque un changement (statut, terrain, fuite...) : prevent_change accepte un bloc pour le message.
    def ea_prevent(handler, &block)
      return handler.prevent_change(&block)
    rescue ArgumentError
      return :prevent
    end
  end

  module_function

  def log_error(where, error)
    text = "[ExtraAbilitiesAdditions] #{where} : #{error.class} #{error.message}"
    Kernel.respond_to?(:log_error, true) ? Kernel.send(:log_error, text) : puts(text)
  end

  def text(fr, en)
    return $options.language.to_s == 'fr' ? fr : en
  rescue StandardError
    return en
  end

  def weather(logic)
    return logic.weather_effect.db_symbol
  rescue StandardError
    return $env.current_weather_db_symbol
  end

  # Supprime des effets de terrain / des deux camps : names = liste de noms d'effets (Symbol).
  def clear_effects(logic, names)
    removed = false
    logic.bank_effects.each do |bank_effect|
      bank_effect.each do |effect|
        next unless names.include?(effect.name)

        effect.kill
        removed = true
      end
    end
    logic.terrain_effects.each do |effect|
      next unless names.include?(effect.name)

      effect.kill
      removed = true
    end
    return removed
  end

  # Crée et enregistre un talent. parent : nom (Symbol) d'un talent PSDK dont on hérite (ex. :Levitate), facultatif.
  def define(symbol, parent = nil, &block)
    base = Battle::Effects::Ability
    superclass = base
    superclass = base.const_get(parent, false) if parent && base.const_defined?(parent, false)
    klass = Class.new(superclass)
    klass.include(Helpers)
    klass.class_eval(&block) if block
    base.register(symbol, klass)
    return klass
  rescue StandardError => e
    log_error("define #{symbol}", e)
  end

  # Puissance des capacités d'un type x mult (en plus : seulement quand les PV sont bas si low_hp).
  def boost(symbol, type, mult, low_hp: false)
    define(symbol) do
      define_method(:base_power_multiplier) do |user, _target, move|
        ea_safe(symbol.to_s, 1) do
          next 1 if user != @target || !ea_type?(move, type)
          next 1 if low_hp && !ea_low_hp?

          next mult
        end
      end
    end
  end

  # Les capacités Normal deviennent de type `to` (puissance x mult).
  def convert(symbol, to, mult = 1.2)
    define(symbol) do
      define_method(:on_move_type_change) do |user, _target, move, type|
        ea_safe(symbol.to_s) do
          new_type = ea_type_id(to)
          next nil if user != @target || new_type.nil? || type != ea_type_id(:normal)

          @converted = move
          next new_type
        end
      end
      define_method(:base_power_multiplier) do |user, _target, move|
        next(user == @target && @converted.equal?(move) ? mult : 1)
      end
    end
  end

  # Absorbe / annule les capacités d'un type : stat (+1) ou soin (fraction des PV max) ou simple immunité.
  def absorb(symbol, type, stat: nil, heal: nil)
    define(symbol) do
      define_method(:on_move_ability_immunity) do |user, target, move|
        ea_safe(symbol.to_s, false) do
          next false if target != @target || user == target || !ea_type?(move, type)

          ea_show(move.scene, target)
          ea_stat(move.logic, stat, 1, target, target) if stat
          ea_heal(move.logic, target, target.max_hp * heal) if heal
          next true
        end
      end
    end
  end
end
