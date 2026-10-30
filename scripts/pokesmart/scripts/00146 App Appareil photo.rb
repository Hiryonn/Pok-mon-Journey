# PokeSmart : appli Appareil photo
#
# Le téléphone se range et laisse voir la carte avec un viseur. A : prendre la photo (capture de l'écran du jeu,
# sans le viseur), B ou clic droit : revenir au téléphone.
# Les photos sont enregistrées dans le dossier PHOTO_DIR du jeu (photo_000.png, photo_001.png…) et listées dans
# la sauvegarde ($user_data[:pokesmart_photos] : fichier, carte, zone, date) pour pouvoir s'en servir en évent.
module UI
  module PokeSmart
    # Affiche l'appli Appareil photo
    CAMERA_APP = true
    # Dossier des photos (dans le dossier du jeu)
    PHOTO_DIR = 'Photos'
    # Taille des photos (1 = 320x240, 2 = 640x480, 3 = 960x720)
    PHOTO_SCALE = 1
    # Textes : [français, anglais]
    CAMERA_HINT = ['A : photo     B : retour', 'A: photo     B: back']
    CAMERA_SAVED = ['Photo %d enregistrée', 'Photo %d saved']
    CAMERA_ERROR = ['Photo impossible', 'Could not take the photo']

    module_function

    # Prend une photo de l'écran (tout ce qui est visible) et l'enregistre
    # @return [Integer] numéro de la photo
    def save_photo
      Dir.mkdir(PHOTO_DIR) unless Dir.exist?(PHOTO_DIR)
      number = 0
      number += 1 while File.exist?(photo_file(number))
      texture = Graphics.snap_to_bitmap
      if PHOTO_SCALE.to_i > 1
        image = Image.new(texture.to_png, true)
        big = Image.new(image.width * PHOTO_SCALE, image.height * PHOTO_SCALE)
        big.stretch_blt!(big.rect, image, image.rect)
        big.to_png_file(photo_file(number))
        [image, big].each(&:dispose)
      else
        texture.to_png_file(photo_file(number))
      end
      texture.dispose
      remember_photo(number)
      return number
    end

    # @param number [Integer]
    # @return [String]
    def photo_file(number)
      return format('%<dir>s/photo_%<n>03d.png', dir: PHOTO_DIR, n: number)
    end

    # Garde la trace de la photo dans la sauvegarde
    # @param number [Integer]
    def remember_photo(number)
      return unless $user_data.is_a?(Hash)

      ($user_data[:pokesmart_photos] ||= []) << {
        file: photo_file(number), map_id: $game_map&.map_id, zone: $env&.current_zone_name.to_s, time: Time.now
      }
    rescue StandardError
      nil
    end

    # Viseur de l'appareil photo
    class Camera < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        @frame = add_sprite(0, 0, PokeSmart.file('camera_frame'))
        @hint = add_text(0, 218, 320, 16, CAMERA_HINT[PokeSmart.french? ? 0 : 1], 1, color: WHITE)
        @message = add_text(0, 196, 320, 16, '', 1, color: WHITE)
        @flash = add_sprite(0, 0, PokeSmart.file('camera_flash'))
        @flash.opacity = 0
        @message_timer = 0
      end

      # Cache le viseur (pendant la photo)
      # @param value [Boolean]
      def overlay_visible=(value)
        [@frame, @hint, @message].each { |sprite| sprite.visible = value }
      end

      # Flash blanc + message après une photo
      # @param text [String]
      def flash(text)
        @flash.opacity = 255
        @message.text = text
        @message_timer = 120
      end

      def update
        @flash.opacity = [@flash.opacity - 24, 0].max if @flash.opacity > 0
        return unless @message_timer > 0

        @message_timer -= 1
        @message.text = '' if @message_timer == 0
      end
    end
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Appareil photo : range le téléphone et affiche le viseur sur la carte
      def open_camera
        @camera = UI::PokeSmart::Camera.new(@viewport)
        @phone.visible = false
        @buttons.each { |button| button.visible = false }
        @background.visible = false if @background.respond_to?(:visible=)
        @__last_scene.spriteset.visible = true if @__last_scene.is_a?(Scene_Map)
      end

      # Retour au téléphone
      def close_camera
        @camera&.dispose
        @camera = nil
        @__last_scene.spriteset.visible = false if @__last_scene.is_a?(Scene_Map)
        @background.visible = true if @background.respond_to?(:visible=)
        @phone.visible = true
        @buttons.each { |button| button.visible = true }
        update_buttons
      end

      private

      # Prend la photo sans le viseur
      def take_photo
        ps = UI::PokeSmart
        @camera.overlay_visible = false
        number = ps.save_photo
        @camera.overlay_visible = true
        play_decision_se
        @camera.flash(format(ps::CAMERA_SAVED[ps.french? ? 0 : 1], number + 1))
      rescue StandardError => e
        log_error("PokeSmart photo : #{e.message}") if respond_to?(:log_error, true)
        @camera&.overlay_visible = true
        play_buzzer_se if respond_to?(:play_buzzer_se, true)
        @camera&.flash(ps::CAMERA_ERROR[ps.french? ? 0 : 1])
      end

      # Appareil photo : A pour la photo, B pour revenir
      def update_camera_inputs
        if Input.trigger?(:A)
          take_photo
        elsif Input.trigger?(:B)
          play_cancel_se
          close_camera
        else
          return true
        end
        return false
      end

      # Appareil photo à la souris : clic gauche pour la photo, clic droit pour revenir
      def update_camera_mouse
        if Mouse.trigger?(:LEFT)
          take_photo
        elsif Mouse.trigger?(:RIGHT)
          play_cancel_se
          close_camera
        end
        return false
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_camera) { UI::PokeSmart::CAMERA_APP } unless ACTION_LIST.include?(:open_camera)
    end
  end
end
