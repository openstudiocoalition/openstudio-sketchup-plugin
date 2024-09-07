########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class ShadowInfoObserver < Sketchup::ShadowInfoObserver

    def initialize(drawing_interface)
      @drawing_interface = drawing_interface  # This is the Building or Site drawing interface
      @shadow_info = @drawing_interface.model_interface.skp_model.shadow_info
      @north_angle = OpenStudio.get_north_angle(@shadow_info)
      @shadow_time = OpenStudio.get_time(@shadow_info)
      @enabled = false
    end

    def disable
      was_enabled = @enabled
      @enabled = false
      return was_enabled
    end

    def enable
      @enabled = true
    end

    def destroy
      @drawing_interface = nil
      @shadow_info = nil
      @north_angle = nil
      @shadow_time = nil
      @enabled = false
    end

    def onShadowInfoChanged(shadow_info, arg2)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      # arg2 is a flag that returns 1 when shadows are displayed.

      proc = Proc.new {

        # check if model has a site, there is no Site object in the default template
        # to avoid setting the location by default
        if not @drawing_interface.model_interface.site
          site = Site.new
          site.create_entity
          site.create_model_object
          site.update_model_object
          site.add_watcher
          site.add_observers
        end

        # Turn on Daylight Saving Time.  Appears that SketchUp does not automatically turn it on.
        if (OpenStudio.get_time(@shadow_info).dst?)
          @shadow_info['DaylightSavings'] = true
        else
          @shadow_info['DaylightSavings'] = false
        end

        # does not call paint
        @drawing_interface.on_change_entity

        if (@drawing_interface.is_a? Site)

          # Only repaint if shadow_time has changed
          if (@shadow_time != OpenStudio.get_time(@shadow_info))
            @shadow_time = OpenStudio.get_time(@shadow_info)
            if (@drawing_interface.model_interface.materials_interface.rendering_mode == RenderByDataValue)
              @drawing_interface.model_interface.request_paint
            end
          end


        elsif (@drawing_interface.is_a? Building)

          # Only repaint if north_angle has changed
          if (@north_angle != OpenStudio.get_north_angle(@shadow_info))
            @north_angle = OpenStudio.get_north_angle(@shadow_info)
            @drawing_interface.model_interface.request_paint
          end

        end

      } # Proc

      Plugin.add_event( proc )

    end

  end

end
