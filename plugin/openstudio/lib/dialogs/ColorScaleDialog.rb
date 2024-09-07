########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/Dialogs")
require("openstudio/lib/dialogs/DialogContainers")


module OpenStudio

  class ColorScaleDialog < Dialog

    def initialize(container, interface, hash)
      super
      h = Plugin.platform_select(380, 400)
      @container = WindowContainer.new("", 112, h, 150, 150)
      @container.set_file(Plugin.dir + "/lib/dialogs/html/ColorScale.html")
      add_callbacks
    end


    def on_load
      super

      if (Plugin.platform == Platform_Mac)
        @container.execute_function("invalidate()")  # Force the WebDialog to redraw
      end
    end


    def update
      super
      if (Plugin.model_manager.model_interface.results_interface.rendering_appearance == "COLOR")
        set_element_source("COLOR_SCALE", "colorscale_vertical.bmp")
      else
        set_element_source("COLOR_SCALE", "grayscale_vertical.bmp")
      end
    end

  end

end
