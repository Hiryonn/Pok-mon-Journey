# Résumé PE : page Stats
module UI
  module SummaryPE
    # Page 1 : aperçu des capacités + stats / IV / EV, nature et talent
    class StatsPage < SpriteStack
      # Première ligne du tableau et hauteur d'une ligne
      ROW_Y = 49
      ROW_HEIGHT = 17
      # Méthodes des valeurs, IV et EV (PV, Atq, Déf, Atq Spé, Déf Spé, Vit)
      VALUES = %i[hp_text atk_basis dfe_basis ats_basis dfs_basis spd_basis]
      IVS = %i[iv_hp_text iv_atk_text iv_dfe_text iv_ats_text iv_dfs_text iv_spd_text]
      EVS = %i[ev_hp_text ev_atk_text ev_dfe_text ev_ats_text ev_dfs_text ev_spd_text]
      # Libellés du fichier 27 pour chaque stat
      LABEL_IDS = [15, 18, 20, 22, 24, 26]
      # Colonnes du tableau (valeur / IV / EV)
      VALUE_X = 163
      VALUE_WIDTH = 64
      IV_X = 231
      EV_X = 275
      COLUMN_WIDTH = 44

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        SummaryPE.widen_page(add_sprite(0, 0, SummaryPE.file('page_stats')), 'page_stats')
        add_text(15, 64, 84, 16, SummaryPE.label(:moves), color: WHITE)
        @slots = Array.new(4) { |i| MoveSlot.new(viewport, SLOT_X, SLOT_Y + i * SLOT_STEP) }
        create_table
      end

      def update; end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        @slots.each_with_index { |slot, i| slot.data = pokemon.skills_set[i] }
        VALUES.each_with_index { |method, i| @values[i].text = pokemon.public_send(method).to_s }
        IVS.each_with_index { |method, i| @ivs[i].text = number_only(pokemon.public_send(method)) }
        EVS.each_with_index { |method, i| @evs[i].text = number_only(pokemon.public_send(method)) }
        @nature.text = pokemon.nature_name.to_s
        @ability.text = pokemon.ability_name.to_s
        refresh_nature(pokemon)
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @slots.each { |slot| slot.visible = value }
        refresh_nature(@data) if value && @data
      end

      private

      # PSDK renvoie « IV: 29 » / « EV: 0 » : on ne garde que le nombre
      # @param text [String, Integer]
      # @return [String]
      def number_only(text)
        return text.to_s.scan(/\d+/).last.to_s
      end

      def create_table
        @values = []
        @ivs = []
        @evs = []
        @signs = []
        e = SummaryPE.extra
        LABEL_IDS.each_with_index do |text_id, i|
          y = ROW_Y + i * ROW_HEIGHT
          label = add_text(104 + e, y, 52, 16, SummaryPE.summary_text(text_id), color: WHITE)
          label.fill_color = Color.new(*STAT_COLORS[i])
          @signs << add_text(157 + e, y, 6, 16, '', color: WHITE)
          @values << add_text(VALUE_X + e, y, VALUE_WIDTH, 16, '', 2, color: WHITE)
          @ivs << add_text(IV_X + e, y, COLUMN_WIDTH, 16, '', 1, color: YELLOW)
          @evs << add_text(EV_X + e, y, COLUMN_WIDTH, 16, '', 1, color: WHITE)
        end
        add_text(104 + e, ROW_Y + 6 * ROW_HEIGHT, 56, 16, SummaryPE.label(:nature), color: WHITE)
        add_text(104 + e, ROW_Y + 7 * ROW_HEIGHT, 56, 16, text_get(33, 142), color: WHITE)
        @nature = add_text(163 + e, ROW_Y + 6 * ROW_HEIGHT, 154, 16, '', 2, color: WHITE)
        @ability = add_text(163 + e, ROW_Y + 7 * ROW_HEIGHT, 154, 16, '', 2, color: WHITE)
      end

      # Colore la stat augmentée (vert, +) et diminuée (rouge, -) par la nature
      # @param pokemon [PFM::Pokemon]
      def refresh_nature(pokemon)
        nature = pokemon.nature.partition.with_index { |_, i| i != 3 }.flatten(1)
        # PV : modificateur du plugin natures_pv (100 si le plugin n'est pas là)
        nature[0] = pokemon.respond_to?(:nature_hp) ? pokemon.nature_hp : 100
        0.upto(5) do |i|
          rate = nature[i].to_i
          color = rate > 100 ? GREEN : (rate < 100 ? RED : WHITE)
          @values[i].load_color(color)
          @signs[i].text = rate > 100 ? '+' : (rate < 100 ? '-' : '')
          @signs[i].load_color(color)
        end
      end
    end
  end
end
