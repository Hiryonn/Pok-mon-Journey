# Résumé PE : page Capacités
module UI
  module SummaryPE
    # Page 2 : capacités sélectionnables + panneau de détails
    class MovesPage < Summary_Skills
      private

      def init_sprite
        push(0, 0, SummaryPE.file('page_moves'))
        add_text(15, 64, 84, 16, SummaryPE.label(:moves), color: WHITE)
        add_text(110, 173, 96, 16, SummaryPE.summary_text(37), color: WHITE)
        add_text(214, 173, 98, 16, SummaryPE.summary_text(39), color: WHITE)
        create_move_info
        @skills = Array.new(4) { |index| SkillButton.new(@viewport, index) }
      end

      def create_move_info
        @move_info = SpriteStack.new(@viewport, default_cache: :interface)
        @move_info.add_text(126, 48, 186, 16, :name, type: SymText, color: WHITE)
        @move_info.add_text(110, 72, 204, 16, :description, type: SymMultilineText, color: WHITE)
        @move_info.push(110, 155, nil, type: TypeSprite)
        @move_info.push(146, 155, nil, type: CategorySprite)
        @move_info.add_text(110, 173, 96, 16, :power_text, 2, type: SymText, color: WHITE)
        @move_info.add_text(214, 173, 98, 16, :accuracy_text, 2, type: SymText, color: WHITE)
      end
    end
  end
end
