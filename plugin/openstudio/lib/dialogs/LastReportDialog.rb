########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/Dialogs")
require("openstudio/lib/dialogs/DialogContainers")


module OpenStudio

  class LastReportDialog < MessageDialog

    def initialize(container, interface, hash)
      super
      @container = WindowContainer.new(Plugin.name + " Last Report Window", 400, 400, 150, 150)
      @container.center_on_parent
      @container.set_file(Plugin.dir + "/lib/dialogs/html/LastReport.html")

      add_callbacks
    end

    def on_load
      super
    end

    def update
      super
    end

  end

end
