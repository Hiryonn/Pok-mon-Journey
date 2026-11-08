# Résumé PE : page Mémo
module UI
  module SummaryPE
    # Page 5 : mémo (date, lieu, niveau de rencontre, nature)
    class MemoPage < SpriteStack
      TEXT_X = 146
      TEXT_Y = 64
      TEXT_WIDTH = 168
      LINE_HEIGHT = 16

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryPE.file('page_memo'))
        @lines = [WHITE, CYAN, WHITE, WHITE].map { |color| add_text(TEXT_X, TEXT_Y, TEXT_WIDTH, 16, '', color: color) }
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        paragraphs = pokemon.egg? ? egg_paragraphs(pokemon) : memo_paragraphs(pokemon)
        y = TEXT_Y
        @lines.each_with_index do |text, i|
          content = paragraphs[i].to_s
          text.visible = !content.empty?
          next if content.empty?

          text.y = y - Text::Util::FOY
          text.multiline_text = content
          y += LINE_HEIGHT * (text.text.count("\n") + 1)
        end
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @lines.each { |text| text.visible = false if text.text.to_s.strip.empty? }
      end

      private

      # @param pokemon [PFM::Pokemon]
      # @return [Array<String>] date, lieu, niveau, nature
      def memo_paragraphs(pokemon)
        nature = nature_sentence(pokemon)
        if (mem = pokemon.memo_text)
          return [custom_memo(pokemon, mem), '', '', nature]
        end

        time = Time.at(pokemon.captured_at.to_i)
        zone = pokemon.captured_zone_name.to_s
        zone = '' if zone.match?(/\A[\s\-_.]*\z/) # lieu inconnu : PSDK renvoie des tirets
        return [time.strftime(SummaryPE.label(:date)), zone,
                format(SummaryPE.label(:met), pokemon.captured_level.to_i), nature]
      end

      # Mémo personnalisé (pokemon.memo_text) : même traitement que PSDK, sans les balises de couleur
      def custom_memo(pokemon, mem)
        time = Time.at(pokemon.captured_at.to_i)
        hash = {'[VAR NUM2(0002)]' => time.strftime('%d'), '[VAR NUM2(0001)]' => time.strftime('%m'), '[VAR NUM2(0000)]' => time.strftime('%Y'),
                '[VAR NUM3(0003)]' => pokemon.captured_level.to_s, '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
        return SummaryPE.strip_markup(parse_text(mem[0] || 28, mem[1] || 25, hash))
      end

      # @param pokemon [PFM::Pokemon]
      # @return [String] ex. « Calme de nature. »
      def nature_sentence(pokemon)
        text = Studio::Text.get(28, 0).dup
        match = text.match(/\[VAR COLOR\(0002\)\]([^\[]*)\[VAR COLOR\(0000\)\]/)
        text.sub!(match[1], pokemon.nature_name.to_s) if match
        return SummaryPE.strip_markup(text)
      rescue StandardError
        return pokemon.nature_name.to_s
      end

      # Textes d'un œuf (repris de UI::Summary_Memo)
      # @param pokemon [PFM::Pokemon]
      def egg_paragraphs(pokemon)
        time = pokemon.egg_at ? Time.at(pokemon.egg_at) : Time.new
        hash = {'[VAR NUM2(0007)]' => time.strftime('%d'), '[VAR NUM2(0002)]' => time.strftime('%d'), '[VAR NUM2(0006)]' => time.strftime('%m'),
                '[VAR NUM2(0001)]' => time.strftime('%m'), '[VAR NUM2(0005)]' => time.strftime('%Y'), '[VAR NUM2(0000)]' => time.strftime('%Y'),
                '[VAR LOCATION(0008)]' => pokemon.egg_zone_name, '[VAR 0105(0008)]' => pokemon.egg_zone_name, '[VAR NUM3(0003)]' => pokemon.captured_level.to_s,
                '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
        how = (pokemon.egg_how_obtained == :received ? 79 : 80) + (pokemon.data.hatch_steps >= 10_240 ? 2 : 0)
        steps = pokemon.step_remaining
        step_id = steps > 10_240 ? 87 : (steps > 2_560 ? 86 : (steps > 1_280 ? 85 : 84))
        return [SummaryPE.strip_markup(parse_text(28, how, hash)), '', '', SummaryPE.strip_markup(parse_text(28, step_id))]
      rescue StandardError
        return ['', '', '', '']
      end
    end
  end
end
