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
  # Liste des quêtes photo (interface pleine largeur aux couleurs du Pokédex Horizon)
  #
  # Haut / bas : quête       molette : quête       clic : choisir       B / A / clic droit : quitter
  class PhotoQuestsScene < GamePlay::BaseCleanUpdate
    ROWS = 8
    ROW_HEIGHT = 22
    LIST_Y = 32
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'

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

    def update_mouse(_moved)
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
        return false
      end
      if Mouse.wheel != 0
        delta = -Mouse.wheel
        Mouse.wheel = 0
        move(delta <=> 0)
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      mouse_x, mouse_y = defined?(::Ecran) ? ::Ecran.souris(@viewport) : [Mouse.x, Mouse.y]
      row = (mouse_y - LIST_Y) / ROW_HEIGHT
      if mouse_x.between?(list_x, list_x + list_w - 1) && mouse_y >= LIST_Y && row < ROWS && @first + row < @quests.size
        select(@first + row)
      end
      return false
    end

    def update_graphics
      return true
    end

    private

    # @return [Integer] x du bord gauche de l'écran
    def left
      return defined?(::Ecran) && ::Ecran.grand? ? ::Ecran.logique_gauche : 0
    end

    # @return [Integer] largeur de l'écran
    def full_width
      return defined?(::Ecran) && ::Ecran.grand? ? ::Ecran.logique_largeur : 320
    end

    # @return [Integer]
    def right
      return left + full_width
    end

    # @return [Integer]
    def list_x
      return left + 6
    end

    # @return [Integer]
    def list_w
      return 150 + (full_width - 320) / 2
    end

    # @return [Integer]
    def card_x
      return list_x + list_w + 6
    end

    # @return [Integer]
    def card_w
      return right - 6 - card_x
    end

    def move(delta)
      return if @quests.empty?

      select((@index + delta) % @quests.size)
    end

    def select(index)
      return if index == @index

      @index = index
      @first = @index < @first ? @index : (@index >= @first + ROWS ? @index - ROWS + 1 : @first)
      play_cursor_se
      refresh
    end

    def stack(x = 0, y = 0)
      return UI::SpriteStack.new(@viewport, x, y, default_cache: :interface)
    end

    def box(width, height, color, border)
      bitmap = Bitmap.new(width, height)
      bitmap.fill_rect(0, 0, width, height, border)
      bitmap.fill_rect(1, 1, width - 2, height - 2, color)
      bitmap.update
      return bitmap
    end

    def create_graphics
      super
      create_frame
      create_list
      create_card
      refresh
    end

    def create_frame
      frame = stack
      wide = full_width / 320.0
      background = RPG::Cache.interface_exist?(BG) ? frame.add_sprite(left, 0, BG) : nil
      if background
        background.zoom_x = wide
      else
        fallback = frame.add_sprite(left, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        fallback.bitmap = Bitmap.new(full_width, 240)
        fallback.bitmap.fill_rect(0, 0, full_width, 240, Color.new(229, 243, 250))
      end
      if RPG::Cache.interface_exist?(HEADER)
        header = frame.add_sprite(0, 0, HEADER)
        add_disposable(*::Ecran.elargir_plaque(header, 80, 240)) if defined?(::Ecran) && ::Ecran.cadre?(@viewport)
      end
      if RPG::Cache.interface_exist?(FOOTER)
        footer = frame.add_sprite(left, 214, FOOTER)
        footer.zoom_x = wide
      end
      fr = UI::PokeSmart::PhotoQuests.fr?
      frame.add_text(96, 5, 128, 16, fr ? 'QUÊTES PHOTO' : 'PHOTO QUESTS', 1, color: WHITE)
      frame.with_font(SMALL) do
        @counter = frame.add_text(right - 88, 7, 82, 13, '', 2, color: WHITE)
        frame.add_text(left + 8, 220, full_width - 16, 13, fr ? 'Haut/Bas : quête   B : quitter' : 'Up/Down: quest   B: quit', 1, color: WHITE)
      end
    end

    def create_list
      @normal = box(list_w, ROW_HEIGHT - 2, Color.new(244, 250, 253), Color.new(150, 185, 205))
      @selected = box(list_w, ROW_HEIGHT - 2, Color.new(70, 130, 190), Color.new(40, 90, 150))
      @rows = Array.new(ROWS) do |i|
        row = stack(list_x, LIST_Y + i * ROW_HEIGHT)
        back = row.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
        back.bitmap = @normal
        name = row.add_text(6, 1, list_w - 12, 16, '', color: DARK)
        name_selected = row.add_text(6, 1, list_w - 12, 16, '', color: WHITE)
        { stack: row, back: back, name: name, name_selected: name_selected }
      end
    end

    def create_card
      @card = stack(card_x, LIST_Y)
      back = @card.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE)
      back.bitmap = box(card_w, ROWS * ROW_HEIGHT - 2, Color.new(250, 252, 254), Color.new(150, 185, 205))
      @card_title = @card.add_text(8, 6, card_w - 16, 16, '', color: DARK)
      @card.with_font(SMALL) do
        @card_text = @card.add_text(8, 30, card_w - 16, 13, '', color: DARK)
        @card_progress = @card.add_text(8, 112, card_w - 16, 13, '', color: DARK)
        @card_reward = @card.add_text(8, 128, card_w - 16, 13, '', color: DARK)
        @card_state = @card.add_text(8, 152, card_w - 16, 13, '', 2, color: DARK)
      end
    end

    # @param quest [Hash]
    # @return [String] récompense lisible
    def reward_text(quest)
      reward = quest['reward']
      return '' unless reward.is_a?(Hash)

      parts = []
      parts << "#{reward['money']} ₽" if reward['money'].to_i > 0
      if reward['item']
        name = begin
          data_item(reward['item'].to_sym).exact_name
        rescue StandardError
          reward['item'].to_s
        end
        parts << "#{name} x#{[reward['count'].to_i, 1].max}"
      end
      return '' if parts.empty?

      return (UI::PokeSmart::PhotoQuests.fr? ? 'Récompense : ' : 'Reward: ') + parts.join(' + ')
    end

    def refresh
      pq = UI::PokeSmart::PhotoQuests
      fr = pq.fr?
      @counter.text = @quests.empty? ? '' : "#{@index + 1} / #{@quests.size}"
      @rows.each_with_index do |row, i|
        quest = @quests[@first + i]
        row[:stack].visible = !quest.nil?
        next unless quest

        selected = @first + i == @index
        row[:back].bitmap = selected ? @selected : @normal
        mark = pq.done?(quest) ? '✔' : '☐'
        label = "#{mark} #{pq.text(quest['name'])}".tr('’‘', "''")
        row[:name].text = label
        row[:name_selected].text = label
        row[:name].visible = !selected
        row[:name_selected].visible = selected
      end
      quest = @quests[@index]
      @card_title.text = quest ? pq.text(quest['name']) : (fr ? 'Aucune quête photo.' : 'No photo quests.')
      @card_text.multiline_text = quest ? pq.text(quest['description']).tr('’‘', "''") : ''
      goal = quest ? pq.goal(quest) : 0
      @card_progress.text = quest ? "#{fr ? 'Photos' : 'Photos'} : #{[pq.progress(quest), goal].min} / #{goal}" : ''
      @card_reward.text = quest ? reward_text(quest) : ''
      @card_state.text = quest && pq.done?(quest) ? (fr ? 'Terminée !' : 'Completed!') : ''
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
