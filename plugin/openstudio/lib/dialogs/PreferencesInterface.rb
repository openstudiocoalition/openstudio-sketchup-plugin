########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2023, OpenStudio Coalition and other contributors. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
#  disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative works
#  may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without specific prior
#  written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED
#  STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
