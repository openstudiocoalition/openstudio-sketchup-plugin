########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/Dialogs")
require("openstudio/lib/dialogs/DialogContainers")


module OpenStudio

  class AboutDialog < MessageDialog

    def initialize(container, interface, hash)
      super
      @container = WindowContainer.new(Plugin.name, 400, 600, 150, 150, false, false)
      @container.center_on_parent
      @container.set_file(Plugin.dir + "/lib/dialogs/html/About.html")

      add_callbacks
    end


    def show
      @container.show_modal
    end

  end

end
