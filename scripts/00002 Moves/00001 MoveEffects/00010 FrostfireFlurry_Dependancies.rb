module PFM
    class Pokemon
        def type_steel?
            return type?(data_type(:steel).id)
        end
    end
end
