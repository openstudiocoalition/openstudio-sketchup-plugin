########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/ColorScaleDialog")


module OpenStudio

  class ColorScaleInterface < DialogInterface

    def initialize
      super

      @dialog = ColorScaleDialog.new(nil, self, @hash)
    end


    def populate_hash

      maximum = Plugin.model_manager.model_interface.results_interface.range_maximum.to_f
      minimum = Plugin.model_manager.model_interface.results_interface.range_minimum.to_f
      units = Plugin.model_manager.model_interface.results_interface.range_units.to_s
      normalize = Plugin.model_manager.model_interface.results_interface.normalize

      tick = (maximum - minimum) / 5.0

      if normalize
        units += "/m2"
      end

      @hash['LABEL_1'] = (maximum).to_s + " " + units
      @hash['LABEL_2'] = (maximum - tick).to_s + " " + units
      @hash['LABEL_3'] = (maximum - tick * 2).to_s + " " + units
      @hash['LABEL_4'] = (maximum - tick * 3).to_s + " " + units
      @hash['LABEL_5'] = (maximum - tick * 4).to_s + " " + units
      @hash['LABEL_6'] = (maximum - tick * 5).to_s + " " + units
    end

  end

end
