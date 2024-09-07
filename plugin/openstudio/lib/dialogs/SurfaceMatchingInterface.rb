########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/SurfaceMatchingDialog")

module OpenStudio

  class SurfaceMatchingInterface < DialogInterface

    def initialize
      super
      @dialog = SurfaceMatchingDialog.new(nil, self, @hash)
    end

  end

end
