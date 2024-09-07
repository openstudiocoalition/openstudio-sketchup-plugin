########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/Dialogs")
require("openstudio/lib/dialogs/DialogContainers")


module OpenStudio

  class PreferencesDialog < PropertiesDialog

    def initialize(container, interface, hash)
      super
      w = Plugin.platform_select(550, 600)
      h = Plugin.platform_select(550, 600)
      @container = WindowContainer.new("Preferences", w, h, 150, 220)
      @container.set_file(Plugin.dir + "/lib/dialogs/html/Preferences.html")

      add_callbacks
    end


    def add_callbacks
      super
      @container.web_dialog.add_action_callback("on_browse_openstudio_dir") { browse_openstudio_dir }
    end

    def browse_openstudio_dir
      openstudio_dir = @hash['OPENSTUDIO_DIR']

      dir = File.dirname(openstudio_dir)
      file_name = File.basename(openstudio_dir)

      if (not File.exist?(dir))
        dir = ""
      end

      if (path = OpenStudio.open_panel("Locate OpenStudio Dir", dir, file_name))
        path = path.split("\\").join("/")  # Have to convert the file separator for other stuff to work later
        # Above is a kludge...should allow any separators to be cut and paste into the text box
        @hash['OPENSTUDIO_DIR'] = path
        update
      end
    end

  end

end
