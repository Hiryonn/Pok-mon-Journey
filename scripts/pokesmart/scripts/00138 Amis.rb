# PokeSmart : réseau social (liste d'amis) — données, affinité, messages, quêtes et combats
#
# Les contacts sont créés dans Pokémon Studio (Plugins > Smartphone > onglet Amis) :
#   Data/configs/plugins/pokesmart_friends.json : contacts (personnage, dresseur, affinité, messages…)
#   Data/Text/Dialogs/9101.csv                   : noms des contacts et textes des messages (une colonne par langue)
# L'état du joueur (amis rencontrés, affinité, messages reçus / lus) est dans la sauvegarde ($user_data).
#
# Commandes d'évent (commande « Script » d'un évent) :
#   friend_meet(:lea)              le joueur rencontre Léa : elle apparaît dans la liste d'amis
#   friend_met?(:lea)              Léa est-elle dans la liste ?
#   friend_affinity(:lea)          affinité (0 à 100)
#   friend_add_affinity(:lea, 10)  ajoute (ou retire avec un nombre négatif) de l'affinité
#   friend_affinity?(:lea, 40)     l'affinité atteint-elle 40 ?
#   friend_message(:lea, :merci)   envoie tout de suite le message « merci » (même sans ses conditions)
#   friend_message_read?(:lea, :merci) le joueur a-t-il lu ce message ?
module Configs
  # Contenu de Data/configs/plugins/pokesmart_friends.json
  class PokeSmartFriendsConfig
    attr_accessor :text_file_id, :contacts

    def initialize
      @text_file_id = 9101
      @contacts = []
    end
  end
  register(:pokesmart_friends, 'plugins/pokesmart_friends', :json, false, PokeSmartFriendsConfig)
end

module UI
  module PokeSmart
    # Affiche l'appli Amis
    FRIENDS_APP = true
    # Affinité maximale (5 cœurs = 100)
    FRIEND_MAX_AFFINITY = 100
    # Affinité gagnée : quête acceptée par message, combat gagné / perdu contre un ami
    FRIEND_QUEST_AFFINITY = 5
    FRIEND_BATTLE_WIN_AFFINITY = 3
    FRIEND_BATTLE_LOSE_AFFINITY = 1

    # Données et règles des amis
    module Friends
      CONFIG_FILE = 'Data/configs/plugins/pokesmart_friends.json'

      module_function

      # @return [Configs::PokeSmartFriendsConfig]
      def config
        @config ||= begin
          if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
            Configs.pokesmart_friends
          else
            Configs::PokeSmartFriendsConfig.new
          end
        rescue StandardError, ScriptError => e
          log_error("PokeSmart : amis illisibles (#{e.message})") if respond_to?(:log_error, true)
          Configs::PokeSmartFriendsConfig.new
        end
      end

      # @return [Array<Hash>] contacts définis dans Studio
      def contacts
        return (config.contacts || []).map { |c| c.transform_keys(&:to_sym) }
      end

      # @param id [Symbol, String]
      # @return [Hash, nil]
      def contact(id)
        return contacts.find { |c| c[:id].to_s == id.to_s }
      end

      # État de tous les amis dans la sauvegarde
      # @return [Hash]
      def states
        return {} unless $user_data.is_a?(Hash)

        return ($user_data[:pokesmart_friends] ||= {})
      end

      # État d'un ami (créé au besoin)
      # @param id [Symbol, String]
      # @return [Hash]
      def state(id)
        return states[id.to_sym] ||= { met: false, affinity: 0, inbox: [], read: [], quests: [], last_battle: nil }
      end

      # Texte du fichier de textes des amis
      # @param row [Integer, nil]
      # @return [String, nil]
      def text(row)
        return nil unless row.is_a?(Integer)

        value = ext_text(config.text_file_id || 9101, row)
        return value.is_a?(String) && !value.empty? ? value.gsub(PFM::Text::TRNAME[0], $trainer&.name.to_s) : nil
      rescue StandardError
        return nil
      end

      # @param id [Symbol, String]
      # @return [String]
      def name(id)
        c = contact(id)
        return (c && text(c[:name_row])) || id.to_s.capitalize
      end

      # Amis rencontrés, dans l'ordre de Studio
      # @return [Array<Hash>]
      def friends
        return contacts.select { |c| state(c[:id])[:met] }
      end

      # @param id [Symbol, String]
      def meet(id)
        c = contact(id)
        s = state(id)
        unless s[:met]
          s[:met] = true
          s[:affinity] = (c && c[:start_affinity]).to_i.clamp(0, FRIEND_MAX_AFFINITY)
        end
        deliver(id)
      end

      # @return [Boolean]
      def met?(id)
        return state(id)[:met] ? true : false
      end

      # @return [Integer]
      def affinity(id)
        return state(id)[:affinity].to_i
      end

      # @param id [Symbol, String]
      # @param amount [Integer]
      def add_affinity(id, amount)
        s = state(id)
        s[:affinity] = (s[:affinity].to_i + amount.to_i).clamp(0, FRIEND_MAX_AFFINITY)
        deliver(id)
      end

      # Nombre de cœurs pleins (0 à 5)
      # @return [Integer]
      def hearts(id)
        return (affinity(id) * 5 / FRIEND_MAX_AFFINITY).clamp(0, 5)
      end

      # @return [Array<Hash>] messages du contact
      def messages_of(id)
        c = contact(id)
        return ((c && c[:messages]) || []).map { |m| m.transform_keys(&:to_sym) }
      end

      # @return [Hash, nil]
      def message(id, message_id)
        return messages_of(id).find { |m| m[:id].to_s == message_id.to_s }
      end

      # Messages reçus (du plus ancien au plus récent)
      # @return [Array<Hash>]
      def inbox(id)
        ids = state(id)[:inbox]
        return ids.map { |message_id| message(id, message_id) }.compact
      end

      # Envoie les messages automatiques dont les conditions sont remplies
      # @param id [Symbol, String, nil] un seul ami (nil = tous)
      def deliver(id = nil)
        list = id ? [contact(id)].compact : contacts
        list.each do |c|
          s = state(c[:id])
          next unless s[:met]

          messages_of(c[:id]).each do |m|
            next unless m[:auto] && !s[:inbox].include?(m[:id].to_s) && conditions_ok?(m, s)

            s[:inbox] << m[:id].to_s
          end
        end
      end

      # @return [Boolean]
      def conditions_ok?(message, s)
        return false if s[:affinity].to_i < message[:affinity].to_i

        switch = message[:switch].to_i
        return switch <= 0 || $game_switches[switch] ? true : false
      end

      # Envoie un message tout de suite
      def send_message(id, message_id)
        s = state(id)
        s[:inbox] << message_id.to_s unless s[:inbox].include?(message_id.to_s)
      end

      # @return [Integer] messages non lus (d'un ami ou de tous)
      def unread(id = nil)
        list = id ? [id] : friends.map { |c| c[:id] }
        return list.sum { |friend| (state(friend)[:inbox] - state(friend)[:read]).size }
      end

      # @return [Boolean]
      def read?(id, message_id)
        return state(id)[:read].include?(message_id.to_s)
      end

      # Marque un message comme lu (et donne son affinité la première fois)
      def mark_read(id, message_id)
        s = state(id)
        return if s[:read].include?(message_id.to_s)

        s[:read] << message_id.to_s
        gain = message(id, message_id)&.dig(:affinity_gain).to_i
        add_affinity(id, gain) if gain != 0
      end

      # Quête proposée par un message et pas encore prise
      # @return [Integer, nil] id de la quête
      def quest_offer(id, message)
        return nil unless message && !message[:quest].to_s.empty?
        return nil if state(id)[:quests].include?(message[:id].to_s)

        quest = data_quest(message[:quest].to_s.to_sym)
        return nil if quest.nil? || quest.db_symbol == :__undef__

        quests = PFM.game_state.quests
        return nil if quests.active_quest(quest.id) || quests.finished?(quest.id)

        return quest.id
      rescue StandardError
        return nil
      end

      # @return [Boolean] si la quête a démarré
      def accept_quest(id, message)
        quest_id = quest_offer(id, message)
        return false unless quest_id && PFM.game_state.quests.start(quest_id)

        state(id)[:quests] << message[:id].to_s
        add_affinity(id, FRIEND_QUEST_AFFINITY)
        return true
      end

      # Jour actuel (pour le délai entre deux combats)
      # @return [Integer]
      def today
        return Time.now.to_i / 86_400
      end

      # @return [Boolean] si l'ami peut être défié maintenant
      def can_battle?(id)
        c = contact(id)
        return false unless c && !c[:trainer].to_s.empty?
        return false if affinity(id) < c[:battle_affinity].to_i

        last = state(id)[:last_battle]
        return last.nil? || today - last >= [c[:battle_cooldown_days].to_i, 0].max
      end

      # Combat contre le dresseur de l'ami (lancé quand le menu se ferme)
      # @return [Proc]
      def battle_proc(id)
        c = contact(id)
        return proc do
          trainer = data_trainer(c[:trainer].to_s.to_sym)
          original_bgm = $game_system.battle_bgm
          bgm = Configs.sounds.base_trainer_battle_bgm
          $game_system.battle_bgm = bgm.is_a?(RPG::AudioFile) ? bgm : RPG::AudioFile.new(*bgm)
          $game_variables[Yuki::Var::Trainer_Battle_ID] = trainer.id
          $game_temp.battle_abort = true
          $game_temp.battle_calling = true
          $game_temp.battle_troop_id = 3
          $game_temp.battle_can_escape = false
          $game_temp.battle_can_lose = true
          $game_temp.battle_proc = proc do |result|
            $game_variables[Yuki::Var::Trainer_Battle_ID] = 0
            $game_system.battle_bgm = original_bgm
            state(id)[:last_battle] = today
            add_affinity(id, result == 0 ? FRIEND_BATTLE_WIN_AFFINITY : FRIEND_BATTLE_LOSE_AFFINITY)
          end
          Yuki::FollowMe.set_battle_entry
          Yuki::FollowMe.save_follower_positions
        end
      end
    end
  end
end

# Commandes d'évent
class Interpreter
  # @param id [Symbol, String] identifiant du contact dans Studio
  def friend_meet(id)
    UI::PokeSmart::Friends.meet(id)
  end

  def friend_met?(id)
    UI::PokeSmart::Friends.met?(id)
  end

  def friend_affinity(id)
    UI::PokeSmart::Friends.affinity(id)
  end

  def friend_add_affinity(id, amount)
    UI::PokeSmart::Friends.add_affinity(id, amount)
  end

  def friend_affinity?(id, value)
    UI::PokeSmart::Friends.affinity(id) >= value.to_i
  end

  def friend_message(id, message_id)
    UI::PokeSmart::Friends.send_message(id, message_id)
  end

  def friend_message_read?(id, message_id)
    UI::PokeSmart::Friends.read?(id, message_id)
  end
end
