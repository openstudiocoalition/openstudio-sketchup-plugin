########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/dialogs/DialogInterface")
require("openstudio/lib/dialogs/PreferencesDialog")


module OpenStudio

  class PreferencesInterface < DialogInterface

    def initialize
      super
      @dialog = PreferencesDialog.new(nil, self, @hash)
    end


    def populate_hash
      @hash['CHECK_FOR_UPDATE'] = Plugin.read_pref("Check For Update #{Plugin.version}")
      @hash['NEW_ZONE_FOR_SPACE'] = Plugin.read_pref("New Zone for Space")
      @hash['DISABLE_USER_SCRIPTS'] = Plugin.read_pref("Disable OpenStudio User Scripts")
      @hash['UNIT_SYSTEM'] = Plugin.read_pref("Unit System")
      @hash['OPENSTUDIO_DIR'] = Plugin.read_pref("OpenStudioDir")

      @hash['SHOW_ERRORS_ON_IDF_TRANSLATION'] = Plugin.read_pref("Show Errors on Idf Translation")
      @hash['SHOW_WARNINGS_ON_IDF_TRANSLATION'] = Plugin.read_pref("Show Warnings on Idf Translation")
    end


    def report

      openstudio_dir = @hash['OPENSTUDIO_DIR']

      key_file = nil
      sketchup_version = Sketchup.version.split('.').first.to_i
      if sketchup_version >= 19
        key_file = File.join(openstudio_dir, "Ruby/openstudio_modeleditor.rb")
      else
        key_file = File.join(openstudio_dir, "Ruby/openstudio.rb")
      end

      if (openstudio_dir.nil? or openstudio_dir.empty?)
        # do nothing, assume user wants to clear
      elsif (not File.exist?(openstudio_dir))
        UI.messagebox("WARNING: #{openstudio_dir} does not exist.")
      elsif (not File.exist?(key_file))
        UI.messagebox("WARNING: #{key_file} does not exist.")
      end

      need_update = false
      if @hash['SHOW_WARNINGS_ON_IDF_EXPORT'] and not @hash['SHOW_ERRORS_ON_IDF_EXPORT']
        @hash['SHOW_ERRORS_ON_IDF_EXPORT'] = true
        need_update = true
      end

      Plugin.write_pref("Check For Update #{Plugin.version}", @hash['CHECK_FOR_UPDATE'])
      Plugin.write_pref("New Zone for Space", @hash['NEW_ZONE_FOR_SPACE'])
      Plugin.write_pref("Disable OpenStudio User Scripts", @hash['DISABLE_USER_SCRIPTS'])
      Plugin.write_pref("Unit System", @hash['UNIT_SYSTEM'])
      Plugin.write_pref("OpenStudioDir", @hash['OPENSTUDIO_DIR'])

      Plugin.write_pref("Show Errors on Idf Translation", @hash['SHOW_ERRORS_ON_IDF_TRANSLATION'])
      Plugin.write_pref("Show Warnings on Idf Translation", @hash['SHOW_WARNINGS_ON_IDF_TRANSLATION'])
      if (@hash['UNIT_SYSTEM'] != Plugin.dialog_manager.units_system)
        Plugin.dialog_manager.update_units
      end

      update if need_update

      return(true)
    end

  end

end
