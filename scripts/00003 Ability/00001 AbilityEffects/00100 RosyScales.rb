module Battle
  module Effects
    class Ability
      class RosyScales < Ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end

        def on_status_prevention(handler, status, target, launcher, skill)
          return unless [@target, *logic.adjacent_allies_of(@target)].include?(target)
          return if status == :cure
          return if launcher&.has_ability?(:infiltrator)
          return if %i[flame_orb toxic_orb].include?(target.item_db_symbol)
          return if %i[petal_dance outrage thrash].include?(skill&.db_symbol)
          return if target.effects.has?(:drowsiness)

          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 842, target))
          end
        end

        def on_move_prevention_user(user, targets, move)
          return if user.bank == @target.bank
          return unless move&.priority(user) > 7
          return unless move&.blocable?
          return unless user.can_be_lowered_or_canceled?
          return unless targets.any? { |t| [@target, *logic.adjacent_allies_of(@target)].include?(t) }

          move.scene.visual.show_ability(@target)
          move.scene.visual.wait_for_animation
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 911, user, PFM::Text::MOVE[1] => move.name))
          return :prevent
        end
      end

      register(:rosy_scales, RosyScales)
    end
  end
end
