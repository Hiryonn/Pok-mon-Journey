# Souvenirs : titres en combat
# - Les messages d'envoi (« Go ! Pikachu l'Affamé ! », « Un Pikachu l'Affamé sauvage apparaît ! », changements)
#   montrent le titre, en couleur (title_color, -1 : sans couleur)
# - Quand un Pokémon titré sort, l'icône de son souvenir s'élève au-dessus de lui (battle_icon)
# - Les Pokémon des dresseurs peuvent recevoir un titre (réglage trainers : dresseur, place, souvenir)
module Mementos
  module_function

  # Nom du Pokémon avec son titre, pour les messages de combat
  # @param pokemon [PFM::Pokemon]
  # @param name [String, nil] nom à utiliser (surnom par défaut)
  # @return [String]
  def battle_name(pokemon, name = nil)
    name ||= pokemon.given_name.to_s
    return name unless setting?('battle_titles')

    source = title_source(pokemon)
    return name unless (ribbon = source&.title_ribbon)

    full = full_title(ribbon, source, name)
    return name if full.empty?

    color = setting('title_color').to_i
    return color < 0 ? full : "\\c[#{color}]#{full}\\c[0]"
  rescue StandardError
    return name || pokemon.given_name.to_s
  end

  # Sous Illusion, c'est le titre du Pokémon imité qui s'affiche
  def title_source(pokemon)
    return pokemon.illusion if pokemon.respond_to?(:illusion) && pokemon.illusion

    return pokemon
  end

  # Le temps du bloc, les surnoms des messages d'envoi prennent leur titre
  def with_titles
    previous = @titles
    @titles = true
    return yield
  ensure
    @titles = previous
  end

  def titles?
    return @titles ? true : false
  end

  # Titres des Pokémon des dresseurs (réglage trainers)
  def trainer_titles(battle_info, bank, id_trainer)
    entries = Array(config.trainers)
    return if entries.empty?

    symbol = data_trainer(id_trainer).db_symbol.to_s
    party = battle_info.parties[bank]&.last || []
    entries.each do |entry|
      next unless fetch(entry, :trainer).to_s == symbol

      pokemon = party[fetch(entry, :slot).to_i]
      memento = fetch(entry, :memento).to_s
      next if pokemon.nil? || memento.empty? || !PFM::RIBBONS_DATA[memento.to_sym]

      pokemon.add_ribbon(memento.to_sym)
      pokemon.set_title(memento.to_sym)
    end
  end
end

module PFM
  module Text
    # Surnoms avec titre pendant les messages d'envoi
    module MementoNames
      def set_pknick(value, index = 0)
        value = Mementos.battle_name(value) if value.is_a?(PFM::Pokemon) && Mementos.titles?
        return super(value, index)
      end
    end
    singleton_class.prepend(MementoNames)
  end
end

module Battle
  module Message
    # Messages du début du combat
    module MementoMessages
      def player_sending_pokemon_start
        return Mementos.with_titles { super }
      end

      def trainer_sending_pokemon_start
        return Mementos.with_titles { super }
      end

      def wild_battle_appearance
        return super unless Mementos.setting?('battle_titles')

        foes = @logic.all_battlers.reject { |battler| battler.bank == 0 }
        return super unless foes.any? { |battler| Mementos.title_source(battler)&.title? }

        name, name2, name3 = foes.map { |battler| Mementos.battle_name(battler, battler.name) }
        hash = { PFM::Text::PKNAME[0] => name, PFM::Text::PKNAME[1] => name2, PFM::Text::PKNAME[2] => name3 }
        return @text.parse(18, 1 + @battle_info.wild_battle_reason.to_i % 7, hash) if name2.nil?
        return @text.parse(73, 2, hash) if name3.nil?

        return @text.parse(73, 3, hash)
      end
    end
    singleton_class.prepend(MementoMessages)
  end

  module Actions
    class Switch
      # « Vas-y, Pikachu l'Affamé ! »
      module MementoSwitch
        private

        def switch_in_message
          return super unless Mementos.setting?('battle_titles')

          name = Mementos.battle_name(@with)
          msg_id = @with.from_party? ? (22 + @with.hp % 2) : 18
          hash = { PFM::Text::TRNAME[0] => @scene.battle_info.trainer_name(@with), PFM::Text::PKNICK[0] => name,
                   PFM::Text::PKNICK[1] => name }
          @scene.display_message_and_wait(parse_text(18, msg_id, hash))
        end
      end
      prepend MementoSwitch
    end
  end

  class Logic
    class BattleInfo
      # Titres des Pokémon des dresseurs
      module MementoTrainers
        def add_trainer(battle_info, bank, id_trainer)
          result = super
          Mementos.safely('dresseurs') { Mementos.trainer_titles(battle_info, bank, id_trainer) }
          return result
        end
      end
      singleton_class.prepend(MementoTrainers)
    end
  end
end

module BattleUI
  # L'icône du souvenir s'élève au-dessus du Pokémon qui sort
  class PokemonSprite
    module MementoIcon
      def dispose
        @memento_sprite.dispose if @memento_sprite && !@memento_sprite.disposed?
        super
      end

      private

      def regular_go_in_animation
        return with_memento(super)
      end

      def follower_go_in_animation
        return with_memento(super)
      end

      def with_memento(animation)
        memento = memento_animation
        return memento ? Yuki::Animation.player(animation, memento) : animation
      rescue StandardError => e
        log_error("Souvenirs : icône en combat (#{e.message})") if respond_to?(:log_error, true)
        return animation
      end

      def memento_animation
        return nil unless Mementos.setting?('battle_icon') && pokemon

        ribbon = Mementos.title_source(pokemon)&.title_ribbon
        name = ribbon && "ribbons/#{ribbon.sprite_name}"
        return nil unless name && RPG::Cache.interface_exist?(name)

        @memento_sprite = nil if @memento_sprite&.disposed?
        sprite = (@memento_sprite ||= Sprite.new(viewport))
        sprite.bitmap = RPG::Cache.interface(name)
        sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
        sprite.zoom = 1.5
        sprite.z = z + 1
        sprite.opacity = 0
        sprite.visible = false
        x, y = sprite_position
        y -= (src_rect.height * sprite_zoom / 2).to_i
        ya = Yuki::Animation
        fade = ya.player(ya.opacity_change(0.15, sprite, 0, 255), ya.wait(0.35), ya.opacity_change(0.25, sprite, 255, 0))
        return ya.player(ya.send_command_to(sprite, :visible=, true),
                         ya.parallel(ya.move(0.75, sprite, x, y, x, y - 56), fade),
                         ya.send_command_to(sprite, :visible=, false))
      end
    end
    prepend MementoIcon
  end
end
