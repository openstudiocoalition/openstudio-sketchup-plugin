########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/AboutDialog")


module OpenStudio

  class AboutInterface < DialogInterface

    def initialize
      super
      @dialog = AboutDialog.new(nil, self, @hash)
    end

    def populate_hash
      @hash['OPENSTUDIO_SKETCHUPPLUGIN_VERSION'] = "#{Plugin.version}"
      @hash['OPENSTUDIO_APPLICATION_DIR'] = "#{Sketchup.read_default("OpenStudio", "OpenStudioDir")}"
      @hash['OPENSTUDIO_VERSION'] = "#{OpenStudio::openStudioVersion}"
    end

  end

end
