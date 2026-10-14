module Battle
    module Effects

    class EffectBase
      def entry_hazard?
        return false
      end
    end
      class Spikes 
          def entry_hazard?
               return true
          end
      end

      class StealthRock
        def entry_hazard?
          return true
        end    
      end

      class StickyWeb
        def entry_hazard?
          return true
        end
      end


        
    end
end