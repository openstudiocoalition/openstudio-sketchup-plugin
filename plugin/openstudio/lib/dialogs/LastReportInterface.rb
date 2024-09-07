########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/LastReportDialog")


module OpenStudio

  class LastReportInterface < DialogInterface

    def initialize
      super
      @dialog = LastReportDialog.new(nil, self, @hash)

      @last_report = ''
      @hash['LAST_REPORT'] = @last_report
    end

    def last_report=(text)
      @last_report = text
      populate_hash
      update
    end

    def populate_hash
      @hash['LAST_REPORT'] = @last_report
      super
    end

    def report
      super
    end



  end

end
