########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/SurfaceSearchDialog")

module OpenStudio

  class SurfaceSearchInterface < DialogInterface

    def initialize
      super
      @dialog = SurfaceSearchDialog.new(nil, self, @hash)
    end

  end

end
