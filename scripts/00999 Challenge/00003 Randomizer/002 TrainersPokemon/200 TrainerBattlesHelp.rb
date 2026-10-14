module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # The class responsible of telling the state of the random wild battles mode
    class TrainersPokemon
      # Method that shows the help
      def help
        cc 0x75
        puts "\r#{'PSDK Randomizer Help'.center(50)}"
        cc 0x07
        print <<~EODESCRIPTION
          Here's the list of the command you can enter in this terminal.
          Remember that you're executing actual Ruby code.
          When an ID is 005 or 023 you have to write 5 or 23, the 0-prefix should never appear in the command you enter.
        EODESCRIPTION
        cc 0x06
        print <<~EOLIST
          \e[31mReminder to always add $randomizer.trainers_pokemon.[your_command] before the following commands!\e[0m
          Check if the random trainer battles mode is enabled:\e[37m
            - enabled?\e[36m
          Enable the random trainer battles mode:\e[37m
            - enable\e[36m
          Disable the random trainer battles mode:\e[37m
            - disable\e[36m
          Get the current mode:\e[37m
            - mode\e[36m
          Switch between shuffle and full random mode:\e[37m
            - switch\e[36m
          Get the state of the mega persistence mode:\e[37m
            - mega_persistence\e[36m
          Set the state of the mega persistence mode:\e[37m
            - mega_persistence = true/false\e[37m
        EOLIST
      end
    end
  end
end
