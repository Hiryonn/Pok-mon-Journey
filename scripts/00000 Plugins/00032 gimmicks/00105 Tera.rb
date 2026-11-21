# Gimmicks : Téracristal
#
# - Chaque Pokémon a un type Téra (choisi au hasard parmi ses types la première fois, réglable par commande
#   d'évènement ou dans Studio) ; « stellar » = type Stellaire.
# - Une fois Téracristallisé (jusqu'à la fin du combat, même s'il est rappelé) : le Pokémon n'a plus que son type
#   Téra en défense (sauf Stellaire), ses attaques de ce type ont le bonus de type (x2 si c'était déjà un de ses
#   types), une attaque de ce type de moins de 60 de puissance passe à 60, Téra Explosion prend ce type.
# - Stellaire : garde ses types en défense ; la première attaque de chaque type est boostée (x2 pour ses types,
#   x1,2 pour les autres).
# - Orbe Téracristal : se vide quand le joueur l'utilise, se recharge quand l'équipe est soignée (centre Pokémon).
module Gimmicks
  module Tera
    STELLAR = :stellar
    # Types Téra possibles (images d'Essentials)
    TYPES = %i[normal fighting flying poison ground rock bug ghost steel fire water grass electric psychic ice dragon dark
               fairy stellar].freeze
    # L'Orbe Téracristal doit être rechargée (soins de l'équipe) après chaque utilisation
    ORB_RECHARGE = true
    # Formes Téracristal : Ogerpon (masques 0..3 → 4..7), Terapagos (forme Stellaire 2)
    FORMS = { ogerpon: ->(form) { form < 4 ? form + 4 : form }, terapagos: ->(_form) { 2 } }.freeze
    # Couleur du Pokémon pendant la cinématique (Stellaire : arc-en-ciel → blanc)
    COLORS = {
      normal: [168, 168, 120], fighting: [192, 48, 40], flying: [168, 144, 240], poison: [160, 64, 160],
      ground: [224, 192, 104], rock: [184, 160, 56], bug: [168, 184, 32], ghost: [112, 88, 152], steel: [184, 184, 208],
      fire: [240, 128, 48], water: [104, 144, 240], grass: [120, 200, 80], electric: [248, 208, 48],
      psychic: [248, 88, 136], ice: [152, 216, 216], dragon: [112, 56, 248], dark: [112, 88, 72], fairy: [238, 153, 172],
      stellar: [255, 255, 255]
    }.freeze
    TEXTS = {
      done: ['%<name>s se Téracristallise en type %<type>s !', '%<name>s Terastallized into the %<type>s type!'],
      stellar: %w[Stellaire Stellar]
    }.freeze

    module_function

    # @param pokemon [PFM::Pokemon, PFM::PokemonBattler]
    # @return [Symbol]
    def tera_type(pokemon)
      pokemon = pokemon.original if pokemon.respond_to?(:original) && pokemon.original
      return pokemon.pj_tera_type
    end

    # @param battler [PFM::PokemonBattler]
    # @param _logic [Battle::Logic]
    def possible?(battler, _logic)
      return false if battler.pj_tera?
      return false if battler.from_player_party? && !orb_charged?

      return true
    end

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    # @param _action [Battle::Actions::PJGimmick]
    def execute(scene, battler, _action)
      type = tera_type(battler)
      if Gimmicks.cinematic?
        Cinematic.new(scene, battler).play(:tera) { battler.pj_terastallize!(type) }
      else
        battler.pj_terastallize!(type)
        scene.visual.battler_sprite(battler.bank, battler.position)&.pokemon = battler
        scene.visual.refresh_info_bar(battler)
      end
      Gimmicks.save_data[:tera_used] = true if battler.from_player_party? && Gimmicks.setting('tera_orb_recharge', ORB_RECHARGE)
      scene.display_message_and_wait(format(text(:done), name: battler.given_name, type: type_name(type)))
    end

    # @return [Boolean] Orbe Téracristal chargée
    def orb_charged?
      return !Gimmicks.save_data[:tera_used]
    end

    # Recharge l'Orbe (soins de l'équipe)
    def recharge
      Gimmicks.save_data[:tera_used] = false
    end

    # @param type [Symbol]
    # @return [String]
    def type_name(type)
      return text(:stellar) if type == STELLAR

      return data_type(type).name
    end

    # @param type [Symbol]
    # @return [Integer] id du type (0 pour Stellaire / inconnu)
    def type_id(type)
      return 0 if type == STELLAR

      return data_type(type).id
    rescue StandardError
      return 0
    end

    # @param key [Symbol]
    def text(key)
      return TEXTS[key][$options&.language == 'fr' ? 0 : 1]
    rescue StandardError
      return TEXTS[key].first
    end

    # Type Téra de départ : un des types du Pokémon (Ogerpon : selon le masque, Terapagos : Stellaire)
    # @param pokemon [PFM::Pokemon]
    # @return [Symbol]
    def default_type(pokemon)
      custom = Gimmicks.species_config(pokemon.db_symbol)['tera'].to_s
      return custom.to_sym unless custom.empty?

      case pokemon.db_symbol
      when :terapagos then return STELLAR
      when :ogerpon then return %i[grass water fire rock][pokemon.form.to_i % 4]
      end
      types = [pokemon.type1, pokemon.type2].reject { |t| t.to_i == 0 }.map { |t| data_type(t).db_symbol }
      types = types.select { |t| TYPES.include?(t) }
      return types.sample || :normal
    end
  end
  register(:tera, Tera)
end

module PFM
  class Pokemon
    # @return [Symbol] type Téra
    def pj_tera_type
      @pj_tera_type ||= Gimmicks::Tera.default_type(self)
    end

    # @param type [Symbol, String]
    def pj_tera_type=(type)
      @pj_tera_type = type&.to_sym
    end
  end

  class GameState
    module PJGimmicksTera
      # Les soins de l'équipe rechargent l'Orbe Téracristal
      def heal_party
        super
        Gimmicks::Tera.recharge
      end
    end
    prepend PJGimmicksTera
  end

  class PokemonBattler
    # @return [Symbol, nil] type Téra une fois Téracristallisé
    attr_reader :pj_tera
    # @return [Array<Integer>] types avant le Téracristal (bonus de type, Stellaire)
    attr_reader :pj_tera_base_types

    # @return [Boolean]
    def pj_tera?
      return !@pj_tera.nil?
    end

    # @return [Boolean]
    def pj_stellar?
      return @pj_tera == Gimmicks::Tera::STELLAR
    end

    # @param type [Symbol]
    def pj_terastallize!(type)
      @pj_tera_base_types = [type1, type2, type3].map(&:to_i).reject(&:zero?)
      @pj_stellar_used = []
      change = Gimmicks::Tera::FORMS[db_symbol]
      if change
        @pj_tera_form = @form
        @form = change.call(@form.to_i)
      end
      @pj_tera = type
    end

    # Fin du combat : forme d'origine
    def pj_end_tera
      @form = @pj_tera_form if @pj_tera_form
      @pj_tera_form = nil
      @pj_tera = nil
    end

    # Stellaire : premier usage d'un type
    # @param type [Integer]
    # @return [Boolean]
    def pj_stellar_first_use?(type)
      return false if (@pj_stellar_used ||= []).include?(type)

      @pj_stellar_used << type unless db_symbol == :terapagos
      return true
    end

    module PJGimmicksTeraTypes
      def type1
        return Gimmicks::Tera.type_id(@pj_tera) if @pj_tera && !pj_stellar?

        return super
      end

      def type2
        return 0 if @pj_tera && !pj_stellar?

        return super
      end

      def type3
        return 0 if @pj_tera && !pj_stellar?

        return super
      end
    end
    prepend PJGimmicksTeraTypes
  end
end

module Battle
  class Move
    module PJGimmicksTera
      private

      # Bonus de type du Téracristal
      def calc_stab(user, types)
        return super unless user.respond_to?(:pj_tera?) && user.pj_tera?

        move_types = types.map(&:to_i).reject(&:zero?)
        base = user.pj_tera_base_types || []
        adapt = user.has_ability?(:adaptability)
        if user.pj_stellar?
          type = move_types.first.to_i
          first = user.pj_stellar_first_use?(type)
          return base.include?(type) ? (first ? 2 : 1.5) : (first ? 1.2 : 1)
        end
        tera = Gimmicks::Tera.type_id(user.pj_tera)
        if move_types.include?(tera)
          return base.include?(tera) ? (adapt ? 2.25 : 2) : (adapt ? 2 : 1.5)
        end
        return move_types.any? { |t| base.include?(t) } ? 1.5 : 1
      end

      # Attaques du type Téra de moins de 60 de puissance : 60 (sauf attaques prioritaires et à coups multiples)
      def calc_base_power(user, target)
        result = super
        return result unless user.respond_to?(:pj_tera?) && user.pj_tera? && !user.pj_stellar?
        return result if priority(user) > 0 || respond_to?(:hit_amount, true)
        return result unless definitive_types(user, target).include?(Gimmicks::Tera.type_id(user.pj_tera))

        base = real_base_power(user, target)
        return result if base <= 0 || base >= 60

        return (result * 60.0 / base).floor
      end
    end
    prepend PJGimmicksTera

    # Téra Explosion : type Téra, physique si l'Attaque est plus haute que l'Attaque Spéciale
    class TeraBlast < Basic
      def deal_damage(user, actual_targets)
        @pj_physical = user.pj_tera? && user.atk_basis > user.ats_basis
        return super
      end

      def physical?
        return @pj_physical ? true : (@pj_physical.nil? ? super : false)
      end

      def special?
        return @pj_physical ? false : (@pj_physical.nil? ? super : true)
      end

      def real_base_power(user, target)
        return user.pj_tera? && user.pj_stellar? ? 100 : super
      end

      def definitive_types(user, target)
        return super unless user.pj_tera? && !user.pj_stellar?

        return [Gimmicks::Tera.type_id(user.pj_tera)]
      end
    end
    Move.register(:s_tera_blast, TeraBlast)
  end
end
