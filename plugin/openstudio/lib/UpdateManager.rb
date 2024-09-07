########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class PluginUpdateManager < OpenStudio::Modeleditor::GithubReleases

    def initialize(verbose)
      super("openstudiocoalition", "openstudio-sketchup-plugin")
      @verbose = verbose
      Sketchup.status_text = "OpenStudio checking for update"

      proc = Proc.new {
        self.waitForFinished
        self.onFinished
      }

      Plugin.add_event( proc )
    end

    def onFinished
      if not self.error
        if (self.newReleaseAvailable)
          button = UI.messagebox("A newer version of the OpenStudio SketchUp Plug-in is ready for download.\n" +
                "Do you want to update to the newer version?\n\n" +
                "Click YES to visit the OpenStudio SketchUp Plug-in website.\n" +
                "Click NO to skip this version and not ask you again.\n" +
                "Click CANCEL to remind you again next time.", MB_YESNOCANCEL)
          if (button == 6)  # YES
            UI.openURL(self.releasesUrl)
          elsif (button == 7)  # NO
            Plugin.write_pref("Check For Update #{Plugin.version}", false)
          end
        elsif (@verbose)
          UI.messagebox("You currently have the most recent version of the OpenStudio SketchUp Plug-in.")
        else
          puts "You currently have the most recent version of the OpenStudio SketchUp Plug-in."
        end
      elsif (@verbose)
        UI.messagebox("Error occurred while checking for update.")
      else
        puts "Error occurred while checking for update."
      end

      Plugin.update_manager = nil

    end

  end

end
