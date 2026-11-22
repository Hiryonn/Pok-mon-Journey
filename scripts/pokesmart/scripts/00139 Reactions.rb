# PokeSmart : réactions des amis
#
# Les amis déjà rencontrés (liste d'amis) envoient un message dans l'appli Amis :
#   - quand un Pokémon est purifié (Obscurs) ou entre en furie ;
#   - pour prévenir d'un Pokémon Obscur, d'une apparition massive ou d'un raid sur la carte où se trouve le joueur : ils le
#     font aussi apparaître (tip_spawn), à l'arrivée sur une carte (tip_chance % de chances, délai tip_cooldown_minutes).
# Les textes sont dans Data/configs/plugins/pokesmart_reactions.json (settings.texts : { clé => { fr: [..], en: [..] } }) ;
# « %s » = nom du Pokémon (réactions) ou de la zone (conseils). Les plugins Obscurs, Pokémon visibles et Raids sont facultatifs.
module Configs
  class PokeSmartReactionsConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:pokesmart_reactions, 'plugins/pokesmart_reactions', :json, false, PokeSmartReactionsConfig)
end

module UI
  module PokeSmart
    module Reactions
      CONFIG_FILE = 'Data/configs/plugins/pokesmart_reactions.json'
      DEFAULTS = {
        'enabled' => true, 'min_affinity' => 0, 'purified_chance' => 100, 'fury_chance' => 60, 'cooldown_seconds' => 120,
        'tip_chance' => 8, 'tip_cooldown_minutes' => 20, 'tip_spawn' => true, 'tip_raid_obscur' => 50,
        'tip_kinds' => %w[obscur outbreak raid], 'affinity_gain' => 1
      }.freeze
      TEXTS = {
        'purified' => { 'fr' => ['J’ai appris que %s a été purifié ! Bravo, ça se fête !', 'Alors c’est vrai, %s est purifié ? Chapeau !'],
                        'en' => ['I heard %s was purified! Congrats!', 'So %s is purified? Hats off!'] },
        'fury' => { 'fr' => ['Fais attention : %s est entré en furie !', 'Eh, %s a l’air hors de contrôle… tout va bien ?'],
                    'en' => ['Careful: %s went into a frenzy!', 'Hey, %s looks out of control… are you OK?'] },
        'obscur' => { 'fr' => ['Une aura sombre rôde du côté de %s… Un Pokémon Obscur est dans le coin !'],
                      'en' => ['A dark aura is lurking around %s… a Shadow Pokémon is nearby!'] },
        'outbreak' => { 'fr' => ['Il y a un attroupement de Pokémon vers %s ! Va voir !'],
                        'en' => ['Lots of Pokémon are gathering around %s! Go take a look!'] },
        'raid' => { 'fr' => ['Un antre de raid s’est rempli vers %s, ça a l’air costaud !'],
                    'en' => ['A raid den has filled up around %s, it looks tough!'] }
      }.freeze

      module_function

      def pending
        return @pending
      end

      def pending=(value)
        @pending = value
      end

      def settings
        @settings ||= begin
          if PSDK_CONFIG.release?
            Configs.pokesmart_reactions.settings || {}
          elsif File.exist?(CONFIG_FILE)
            require 'json'
            data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
            data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings'] : {}
          else
            {}
          end
        rescue StandardError, ScriptError => e
          log_error("PokeSmart : réactions illisibles (#{e.message})") if respond_to?(:log_error, true)
          {}
        end
      end

      def setting(key)
        value = settings[key.to_s]
        return value.nil? ? DEFAULTS[key.to_s] : value
      end

      # @return [String] texte d'une réaction (au hasard), dans la langue du jeu
      def pick_text(kind, arg)
        texts = settings['texts'].is_a?(Hash) ? settings['texts'][kind.to_s] : nil
        texts = TEXTS[kind.to_s] unless texts.is_a?(Hash)
        lang = $options && $options.language.to_s != 'fr' ? 'en' : 'fr'
        list = Array(texts[lang]).reject { |t| t.to_s.empty? }
        list = Array(TEXTS[kind.to_s][lang]) if list.empty?
        return format(list.sample.to_s, arg.to_s)
      rescue StandardError
        return list.to_a.sample.to_s
      end

      def memory
        return ($user_data[:pj_reactions] ||= { 'last' => {}, 'seq' => 0 })
      end

      # Un ami déjà rencontré envoie un message libre
      # @return [Boolean]
      def send_from_friend(kind, arg)
        friends = Friends.friends.select { |c| Friends.affinity(c[:id]) >= setting('min_affinity').to_i }
        return false if friends.empty?

        friend = friends.sample
        memory['seq'] += 1
        mid = "reaction_#{memory['seq']}"
        Friends.add_dynamic(friend[:id], mid, pick_text(kind, arg), setting('affinity_gain').to_i)
        return true
      rescue StandardError => e
        log_error("PokeSmart : réaction (#{e.message})") if respond_to?(:log_error, true)
        return false
      end

      # Réaction à un évènement (purification, furie), avec un délai pour ne pas inonder la boîte
      def react(kind, pokemon)
        return unless setting('enabled') && rand(100) < setting("#{kind}_chance").to_i

        now = Time.now.to_i
        return if now - memory['last'][kind.to_s].to_i < setting('cooldown_seconds').to_i

        memory['last'][kind.to_s] = now if send_from_friend(kind, pokemon.given_name)
      end

      # Conseil à l'arrivée sur une carte (et apparition correspondante)
      def tip(map)
        return unless setting('enabled') && rand(100) < setting('tip_chance').to_i
        return if Friends.friends.empty?

        now = Time.now.to_i
        return if now - memory['last']['tip'].to_i < setting('tip_cooldown_minutes').to_i * 60

        kinds = Array(setting('tip_kinds')).map(&:to_s).shuffle
        kinds.each do |kind|
          next unless setting('tip_spawn') ? spawn(kind, map) : available?(kind)

          memory['last']['tip'] = now if send_from_friend(kind, $env.current_zone_name)
          break
        end
      rescue StandardError => e
        log_error("PokeSmart : conseil (#{e.message})") if respond_to?(:log_error, true)
      end

      def available?(kind)
        case kind
        when 'obscur' then defined?(::Obscurs) && defined?(::OverworldPokemon) ? true : false
        when 'outbreak' then defined?(::OverworldPokemon) ? true : false
        when 'raid' then defined?(::Raids) ? true : false
        else false
        end
      end

      # @return [Boolean] l'apparition a eu lieu
      def spawn(kind, map)
        return false unless available?(kind)

        case kind
        when 'obscur' then return spawn_obscur(map)
        when 'outbreak' then return OverworldPokemon.force_outbreak(map).to_i > 0
        when 'raid' then return fill_den(map)
        end
        return false
      end

      def spawn_obscur(map)
        groups = OverworldPokemon.land_groups(OverworldPokemon.zone_of(map.map_id))
        group, encounter, level = OverworldPokemon.roll(groups)
        return false unless group

        tag = OverworldPokemon.tag_value(group.system_tag)
        spot = OverworldPokemon.free_tile(map, tag)
        return false unless spot

        pokemon = OverworldPokemon.make_pokemon(encounter, level, 0, 0)
        ::Obscurs.make_shadow(pokemon)
        id = [map.events.keys.max.to_i + 1, OverworldPokemon.setting('event_id_start').to_i].max
        OverworldPokemon.add_pokemon(map, id, spot, tag, pokemon)
        return true
      end

      def fill_den(map)
        dens = map.events.values.select { |event| ::Raids.den_style(event.event.name) }
        return false if dens.empty?

        event = dens.sample
        style = ::Raids.den_style(event.event.name)
        ::Raids.roll_den(map.map_id, event.id, style, obscur: defined?(::Obscurs) && rand(100) < setting('tip_raid_obscur').to_i)
        return true
      end

      # Installe les hooks sur Obscurs (chargé avant ou après ce plugin)
      def install_hooks
        return if @hooks || !defined?(::Obscurs) || !defined?(PFM::Pokemon) || !PFM::Pokemon.method_defined?(:purify_shadow)

        @hooks = true
        PFM::Pokemon.prepend(PokemonHooks)
        PFM::PokemonBattler.prepend(PokemonHooks) if defined?(PFM::PokemonBattler) && PFM::PokemonBattler.method_defined?(:shadow_fury=)
      end

      module PokemonHooks
        def purify_shadow
          was = shadow?
          result = super
          Reactions.react(:purified, self) if was
          return result
        end

        def shadow_fury=(value)
          was = shadow_fury?
          super
          Reactions.react(:fury, self) if value && !was && shadow_fury?
        end
      end
    end

    module Friends
      module_function

      # Message écrit à la volée (pas défini dans Studio) : « text_row » est ici le texte lui-même
      def add_dynamic(id, message_id, text, affinity_gain = 0)
        s = state(id)
        (s[:dyn] ||= {})[message_id.to_s] = { id: message_id.to_s, text_row: text.to_s, affinity_gain: affinity_gain.to_i }
        s[:inbox] << message_id.to_s unless s[:inbox].include?(message_id.to_s)
      end
    end

    module Friends
      class << self
        module DynamicMessages
          def message(id, message_id)
            dyn = state(id)[:dyn]
            found = dyn && dyn[message_id.to_s]
            return found || super
          end

          def text(row)
            return row.gsub(PFM::Text::TRNAME[0], $trainer&.name.to_s) if row.is_a?(String)

            return super
          end
        end
        prepend DynamicMessages
      end
    end
  end
end

class Game_Map
  module PokeSmartReactions
    def setup(map_id)
      result = super
      UI::PokeSmart::Reactions.install_hooks
      UI::PokeSmart::Reactions.pending = self
      return result
    end
  end
  prepend PokeSmartReactions
end

# Le conseil est donné une fois la carte en place (après l'apparition des Pokémon visibles)
class Scene_Map
  module PokeSmartReactionsTick
    def update
      super
      map = UI::PokeSmart::Reactions.pending
      return unless map

      UI::PokeSmart::Reactions.pending = nil
      UI::PokeSmart::Reactions.tip(map) if map.equal?($game_map)
    end
  end
  prepend PokeSmartReactionsTick
end
