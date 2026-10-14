module Battle
  class Logic
    class ExpHandler
      class Gen2Formula < Gen1Formula
        # Share divisor without encountered count: 2 * n instead of 2 * s * n
        # @param encountered_count [Integer] the number of Pokemon that fought the enemy
        # @param share_receiver_count [Integer] the number of share receivers among eligible
        # @return [Integer] the share divisor
        def calculate_share_divisor(encountered_count, share_receiver_count)
          return 2 * share_receiver_count
        end
      end
    end
  end
end
