# encoding: utf-8
# PokeSmart : quêtes photo (dans l'appli Journal)
#
# Chaque photo de l'appli Appareil photo garde la carte, la zone, l'heure (phase de la journée) et les Pokémon visibles à
# l'écran (espèce, chromatique, endormi) : $user_data[:pokesmart_photos]. Une quête photo est validée en relisant ces
# données : « photographie un Pokémon qui dort la nuit » = une photo prise la nuit où un Pokémon endormi est à l'écran.
# Un Pokémon visible (plugin Pokémon visibles) dort la nuit quand il se promène (tempérament wander) : il ne bouge plus tant
# que le joueur n'est pas tout près, et se réveille alors.
#
# Réglages : Data/configs/plugins/pokesmart_photoquests.json
#   settings   enabled, notify (bannière du téléphone à la validation)
#   quests     [{ id, name: {fr,en}, description: {fr,en}, species: [db_symbol] (vide : toutes), phase: night / morning / day / evening
#              (vide : toute heure), state: sleeping (vide : peu importe), shiny: true (vide : peu importe), zones: [noms de zone],
#              maps: [numéros de carte], count: nombre de photos, reward: { item, count, money } }]
# Le Journal propose « Quêtes » (journal de PSDK) et « Quêtes photo » (cette liste).
# Commandes d'évènement : quete_photo_faite?(:dormeur_nocturne), nombre_quetes_photo, ouvrir_quetes_photo
module Configs
  class PokeSmartPhotoQuestsConfig
    attr_accessor :settings, :quests

    def initialize
      @settings = {}
      @quests = []
    end
  end
  register(:pokesmart_photoquests, 'plugins/pokesmart_photoquests', :json, false, PokeSmartPhotoQuestsConfig)
end

module UI
  module PokeSmart
    module PhotoQuests
      CONFIG_FILE = 'Data/configs/plugins/pokesmart_photoquests.json'
      DEFAULTS = { 'enabled' => true, 'notify' => true }.freeze
      DEFAULT_QUESTS = [
        { 'id' => 'dormeur_nocturne', 'name' => { 'fr' => 'Dormeur nocturne', 'en' => 'Night sleeper' },
          'description' => { 'fr' => 'Photographie un Pokémon qui dort la nuit.', 'en' => 'Photograph a Pokémon sleeping at night.' },
          'phase' => 'night', 'state' => 'sleeping', 'count' => 1, 'reward' => { 'money' => 500 } },
        { 'id' => 'dormeurs', 'name' => { 'fr' => 'Nuit paisible', 'en' => 'Peaceful night' },
          'description' => { 'fr' => 'Photographie 5 Pokémon endormis (5 photos différentes).', 'en' => 'Photograph 5 sleeping Pokémon (5 different photos).' },
          'phase' => 'night', 'state' => 'sleeping', 'count' => 5, 'reward' => { 'money' => 2000 } },
        { 'id' => 'chromatique', 'name' => { 'fr' => 'Éclat sur pellicule', 'en' => 'Shiny on film' },
          'description' => { 'fr' => 'Photographie un Pokémon chromatique.', 'en' => 'Photograph a shiny Pokémon.' },
          'shiny' => true, 'count' => 1, 'reward' => { 'money' => 3000 } }
      ].freeze

      module_function

      def settings_data
        @settings_data ||= begin
          if PSDK_CONFIG.release?
            cfg = Configs.pokesmart_photoquests
            { 'settings' => cfg.settings || {}, 'quests' => cfg.quests }
          elsif File.exist?(CONFIG_FILE)
            require 'json'
            data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
            data.is_a?(Hash) ? data : {}
          else
            {}
          end
        rescue StandardError, ScriptError => e
          log_error("PokeSmart : quêtes photo illisibles (#{e.message})") if respond_to?(:log_error, true)
          {}
        end
      end

      def setting(key)
        value = (settings_data['settings'] || {})[key.to_s]
        return value.nil? ? DEFAULTS[key.to_s] : value
      end

      # @return [Array<Hash>]
      def quests
        list = settings_data['quests']
        return list.is_a?(Array) && !list.empty? ? list : DEFAULT_QUESTS
      end

      def fr?
        return $options.nil? || $options.language.to_s == 'fr'
      end

      def text(hash)
        return hash.to_s unless hash.is_a?(Hash)

        return (hash[fr? ? 'fr' : 'en'] || hash['fr'] || hash['en']).to_s
      end

      # @return [Hash] état sauvegardé : { 'done' => { id => true } }
      def state
        game = PFM.game_state
        data = game.instance_variable_get(:@pj_photoq) || game.instance_variable_set(:@pj_photoq, {})
        return data['done'] ? data : data.merge!('done' => {})
      end

      def photos
        return $user_data.is_a?(Hash) ? Array($user_data[:pokesmart_photos]) : []
      end

      # --- Lecture d'une photo ---------------------------------------------------------------------------
      # Phase de la journée d'une photo (sauvegardée avec elle, sinon d'après l'heure)
      def phase_of(entry)
        return entry[:phase].to_s unless entry[:phase].to_s.empty?

        hour = entry[:time].respond_to?(:hour) ? entry[:time].hour : 12
        return 'morning' if hour.between?(6, 10)
        return 'day' if hour.between?(11, 17)
        return 'evening' if hour.between?(18, 20)

        return 'night'
      end

      # @param entry [Hash] photo
      # @param quest [Hash]
      # @return [Boolean]
      def match?(entry, quest)
        return false unless entry.is_a?(Hash)

        phase = quest['phase'].to_s
        return false unless phase.empty? || phase_of(entry) == phase

        maps = Array(quest['maps']).map(&:to_i)
        return false unless maps.empty? || maps.include?(entry[:map_id].to_i)

        zones = Array(quest['zones']).map { |z| z.to_s.downcase }
        return false unless zones.empty? || zones.include?(entry[:zone].to_s.downcase)

        subjects = Array(entry[:subjects])
        species = Array(quest['species']).map(&:to_s)
        wanted_state = quest['state'].to_s
        needs_subject = !species.empty? || !wanted_state.empty? || !quest['shiny'].nil?
        return true unless needs_subject

        return subjects.any? do |s|
          (species.empty? || species.include?(s[:species].to_s)) &&
            (wanted_state != 'sleeping' || s[:asleep]) &&
            (quest['shiny'].nil? || s[:shiny] == quest['shiny'])
        end
      end

      # @return [Integer] photos qui valident la quête
      def progress(quest)
        return photos.count { |entry| match?(entry, quest) }
      end

      def goal(quest)
        return [quest['count'].to_i, 1].max
      end

      def done?(quest)
        return state['done'][quest['id'].to_s] ? true : false
      end

      # Valide les quêtes accomplies (récompense une seule fois)
      # @return [Array<Hash>] quêtes validées à l'instant
      def check
        return [] unless setting('enabled') && PFM.game_state

        validated = quests.select do |quest|
          next false if done?(quest) || progress(quest) < goal(quest)

          state['done'][quest['id'].to_s] = true
          give_reward(quest['reward'])
          true
        end
        validated.each do |quest|
          next unless setting('notify') && defined?(UI::PokeSmart::Notify)

          UI::PokeSmart::Notify.push(text(quest['name']), title: fr? ? 'Quête photo' : 'Photo quest')
        end
        return validated
      rescue StandardError => e
        log_error("PokeSmart : quêtes photo (#{e.message})") if respond_to?(:log_error, true)
        return []
      end

      def give_reward(reward)
        return unless reward.is_a?(Hash)

        item = reward['item'].to_s
        $bag.add_item(item.to_sym, [reward['count'].to_i, 1].max) if !item.empty? && data_item(item.to_sym).db_symbol != :__undef__
        PFM.game_state.add_money(reward['money'].to_i) if reward['money'].to_i > 0
      end

      # Pokémon visibles à l'écran au moment de la photo
      # @return [Array<Hash>]
      def subjects
        return [] unless defined?(Game_OverworldPokemon) && $game_map

        return $game_map.events.values.select { |event| event.is_a?(Game_OverworldPokemon) && on_screen?(event) }.map do |event|
          pokemon = event.ow_pokemon
          { species: pokemon.db_symbol, form: pokemon.form.to_i, shiny: pokemon.shiny? ? true : false,
            asleep: event.respond_to?(:ow_sleeping?) && event.ow_sleeping? ? true : false }
        end
      rescue StandardError
        return []
      end

      def on_screen?(event)
        return !event.erased && event.screen_x.between?(-8, 328) && event.screen_y.between?(0, 250)
      rescue StandardError
        return false
      end
    end

    # La photo garde la phase de la journée et les Pokémon visibles, puis valide les quêtes
    module PhotoQuestsRecord
      def remember_photo(number)
        super
        entry = $user_data.is_a?(Hash) ? Array($user_data[:pokesmart_photos]).last : nil
        return unless entry.is_a?(Hash)

        entry[:phase] = time_of_day.to_s
        entry[:subjects] = PhotoQuests.subjects
        PhotoQuests.check
      rescue StandardError
        nil
      end
    end
    singleton_class.prepend PhotoQuestsRecord
  end
end

module GamePlay
  # Liste des quêtes photo
  class PhotoQuestsScene < GamePlay::BaseCleanUpdate
    ROWS = 7
    ROW_Y = 14
    ROW_STEP = 24

    def initialize
      super()
      @index = 0
      @first = 0
      @quests = UI::PokeSmart::PhotoQuests.quests
    end

    def update_inputs
      if Input.repeat?(:DOWN)
        move(1)
      elsif Input.repeat?(:UP)
        move(-1)
      elsif Input.trigger?(:B) || Input.trigger?(:A)
        play_cancel_se
        @running = false
      end
      return true
    end

    def update_graphics
      return true
    end

    private

    def move(delta)
      return if @quests.empty?

      @index = (@index + delta) % @quests.size
      @first = @index < @first ? @index : (@index >= @first + ROWS ? @index - ROWS + 1 : @first)
      play_cursor_se
      refresh
    end

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @title = @stack.add_text(8, 0, 304, 14, UI::PokeSmart::PhotoQuests.fr? ? 'Quêtes photo' : 'Photo quests', color: 10)
      @rows = Array.new(ROWS) do |i|
        y = ROW_Y + i * ROW_STEP
        back = @stack.add_sprite(20, y, UI::PokeSmart.file('choice'))
        back.zoom_x = 3
        text = @stack.add_text(24, y + 2, 270, 16, '', 0, color: 0)
        [back, text]
      end
      @panel = @stack.add_sprite(20, 188, UI::PokeSmart.file('choice'))
      @panel.zoom_x = 3
      @panel.zoom_y = 2.4
      @line1 = @stack.add_text(24, 192, 270, 16, '', 0, color: 0)
      @line2 = @stack.add_text(24, 210, 270, 16, '', 0, color: 0)
      refresh
    end

    def refresh
      pq = UI::PokeSmart::PhotoQuests
      @rows.each_with_index do |(back, text), i|
        quest = @quests[@first + i]
        back.visible = text.visible = !quest.nil?
        next unless quest

        back.set_bitmap(UI::PokeSmart.file(@first + i == @index ? 'choice_selected' : 'choice'), :interface)
        mark = pq.done?(quest) ? '✔' : '☐'
        text.text = "#{mark} #{pq.text(quest['name'])}  (#{[pq.progress(quest), pq.goal(quest)].min}/#{pq.goal(quest)})"
      end
      quest = @quests[@index]
      @line1.text = quest ? pq.text(quest['description']) : (pq.fr? ? 'Aucune quête photo.' : 'No photo quests.')
      @line2.text = quest && pq.done?(quest) ? (pq.fr? ? 'Terminée !' : 'Completed!') : ''
    end
  end
end

module GamePlay
  class Menu
    # Journal : « Quêtes » (PSDK) ou « Quêtes photo »
    module PokeSmartPhotoQuestsJournal
      def open_quest
        return super unless UI::PokeSmart::PhotoQuests.setting('enabled')

        fr = UI::PokeSmart::PhotoQuests.fr?
        choice = display_message(fr ? 'Que consulter ?' : 'What to look at?', 1,
                                 fr ? 'Quêtes' : 'Quests', fr ? 'Quêtes photo' : 'Photo quests', fr ? 'Retour' : 'Back')
        return super if choice == 0

        call_scene(GamePlay::PhotoQuestsScene) if choice == 1
      end
    end
    prepend PokeSmartPhotoQuestsJournal
  end
end

class Interpreter
  def quete_photo_faite?(id)
    quest = UI::PokeSmart::PhotoQuests.quests.find { |q| q['id'].to_s == id.to_s }
    return quest ? UI::PokeSmart::PhotoQuests.done?(quest) : false
  end

  def nombre_quetes_photo
    pq = UI::PokeSmart::PhotoQuests
    return pq.quests.count { |quest| pq.done?(quest) }
  end

  def ouvrir_quetes_photo
    $scene.call_scene(GamePlay::PhotoQuestsScene)
  end
end
