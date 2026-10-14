module GamePlay
  # Game variable storing the daycare id used by the Pension UI.
  PENSION_DAYCARE_VARIABLE = 46

  class << self
    # Scene class used by the Pension UI.
    # @return [Class<GamePlay::PensionUI>]
    attr_accessor :pension_ui_class

    # Open the Pension UI.
    # If no daycare id is given, the method keeps the same default behaviour as
    # the custom Regis version and uses game variable 46.
    # @param daycare_id [Integer]
    # @return [void]
    def open_daycare_ui(daycare_id = $game_variables[PENSION_DAYCARE_VARIABLE])
      current_scene.call_scene(pension_ui_class, daycare_id)
    end
  end
end
