# Résumé PE : page Concours
module UI
  module SummaryPE
    # Capacité de la page concours : la condition (Sang-froid, Beauté…) remplace le nom du type
    class ContestSkillButton < SkillButton
      private

      def create_slot_content
        super
        @condition = add_sprite(14, 13, NO_INITIAL_IMAGE, type: ConditionSprite)
      end

      # @param skill [PFM::Skill]
      def show_skill(skill)
        super
        @move_type.text = ''
        @condition.data = skill
      end
    end

    # Page 3 : concours. Liste des capacités comme la page Capacités ; à droite le graphe des
    # conditions (aucune capacité sélectionnée) ou la description de concours de la capacité choisie.
    class ContestPage < Summary_Contest
      # Centre et rayons du pentagone (rayon minimal = condition à 0)
      CENTER = [212, 124]
      RADIUS = 38
      MIN_RADIUS = 3
      # Étiquettes des conditions, dans l'ordre des sommets (haut puis sens horaire)
      LABEL_POSITIONS = [[196, 70], [252, 105], [226, 158], [166, 158], [140, 105]]
      # Cœurs d'attrait / de gêne
      HEART_X = 206
      HEART_STEP = 9

      # @param version [Symbol] :stats (graphe) ou :moves (description)
      def show_page_version(version)
        super
        name = version == :moves ? 'page_moves' : 'page_contest'
        @background.set_bitmap(SummaryPE.file(name), :interface)
        SummaryPE.widen_page(@background, name)
      end

      private

      def init_sprite
        @background = SummaryPE.widen_page(add_sprite(0, 0, SummaryPE.file('page_contest')), 'page_contest')
        add_text(15, 64, 84, 16, SummaryPE.label(:moves), color: WHITE)
        init_stats
        init_move_info
        init_skills
      end

      def init_stats
        @stats_info = SpriteStack.new(@viewport, default_cache: :interface)
        @stats_info.add_text(126, 48, 186 + SummaryPE.extra, 16, SummaryPE.label(:contest), color: WHITE)
        LABEL_POSITIONS.each_with_index do |(x, y), i|
          @stats_info.add_sprite(x, y, NO_INITIAL_IMAGE, i + 1, type: SummaryConditionSprite)
        end
        @stats_info.add_text(110, 182, 56, 16, text_get(27, 66), color: WHITE)
        16.times { |i| @sheen_stars << @stats_info.add_sprite(170 + i * 9, 187, 'contest/star') }
        @pentagon = Shape.new(@viewport, :convex, 5)
        5.times { |i| @pentagon.set_point(i, *pentagon_point(i, MIN_RADIUS)) }
        @pentagon.color = Color.new(*PENTAGON_COLOR)
        @pentagon.outline_color = Color.new(*PENTAGON_OUTLINE_COLOR)
        @pentagon.outline_thickness = PENTAGON_OUTLINE_THICKNESS
      end

      def init_move_info
        texts = text_file_get(27)
        @move_info = SpriteStack.new(@viewport, default_cache: :interface)
        @move_info.add_text(126, 48, 186 + SummaryPE.extra, 16, :name, type: SymText, color: WHITE)
        @move_info.add_text(110, 72, 204 + SummaryPE.extra, 16, :contest_description, type: SymMultilineText, color: WHITE)
        @move_info.add_sprite(110, 153, NO_INITIAL_IMAGE, type: ConditionSprite)
        @move_info.add_text(110, 170, 92, 16, texts[61].to_s, color: WHITE)
        @move_info.add_text(110, 186, 92, 16, texts[62].to_s, color: WHITE)
        8.times do |i|
          heart = @move_info.add_sprite(HEART_X + i * HEART_STEP, 175, 'contest/hearts', 1, 3, type: SpriteSheet)
          heart.sy = 1
          @appeal_hearts << heart
        end
        8.times do |i|
          heart = @move_info.add_sprite(HEART_X + i * HEART_STEP, 191, 'contest/hearts', 1, 3, type: SpriteSheet)
          heart.sy = 2
          @jam_hearts << heart
        end
      end

      def init_skills
        @skills = Array.new(4) { |index| ContestSkillButton.new(@viewport, index) }
      end

      def update_move
        return unless @move_info.data && @move_info.visible && @page_version == :moves

        @appeal_hearts.each_with_index { |sprite, i| sprite.visible = i < @move_info.data.appeal.to_i }
        @jam_hearts.each_with_index { |sprite, i| sprite.visible = i < @move_info.data.jam.to_i }
      end

      def update_stats
        return unless @data && @stats_info.visible && @page_version == :stats

        stars = (@data.sheen.to_f / 16).ceil
        @sheen_stars.each_with_index { |sprite, i| sprite.visible = i < stars }
        update_pentagon
      end

      def update_pentagon
        max_stat = Configs.conditions.max_condition_value.to_f
        max_stat = 255.0 if max_stat <= 0
        @data.contest_conditions.each_with_index do |condition, i|
          radius = MIN_RADIUS + (RADIUS - MIN_RADIUS) * condition.to_f.clamp(0, max_stat) / max_stat
          @pentagon.set_point(i, *pentagon_point(i, radius))
        end
      end

      # @param index [Integer] sommet (0 = haut, sens horaire)
      # @param radius [Float]
      # @return [Array(Float, Float)]
      def pentagon_point(index, radius)
        angle = (-90 + 72 * index) * Math::PI / 180
        return CENTER[0] + radius * Math.cos(angle), CENTER[1] + radius * Math.sin(angle)
      end
    end
  end
end
