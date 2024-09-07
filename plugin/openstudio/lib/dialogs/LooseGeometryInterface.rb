########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/LooseGeometryDialog")

module OpenStudio

  class LooseGeometryInterface < DialogInterface

    def initialize
      super
      @dialog = LooseGeometryDialog.new(nil, self, @hash)
    end

  end

end
