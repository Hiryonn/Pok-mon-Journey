module PFM
    # The InGame Pokemon management
    # @author Nuri Yuri
    class Pokemon
        # Determine the form of Castform
        # @param reason [Symbol]
        def castform_form(reason)
            return 1 if reason == :fire
            return 2 if reason == :rain
            return 3 if reason == :ice
            return 0
        end
    end
end