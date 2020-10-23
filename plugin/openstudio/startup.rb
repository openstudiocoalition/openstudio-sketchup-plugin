########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2020, OpenStudio Coalition and other contributors. All rights reserved.
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

require 'extensions.rb'   # defines the SketchupExtension class

sketchup_version = Sketchup.version.split('.').first.to_i
do_load = true

# check current settings
openstudio_dir = Sketchup.read_default("OpenStudio", "OpenStudioDir")

while true

  if openstudio_dir.nil? || !File.exists?(openstudio_dir)

    prompts = ["Path to OpenStudio Root Directory"]
    is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    if is_windows
      if sketchup_version >= 19
        defaults = Dir.glob('C:/openstudioapplication-*').sort.reverse
      else
        defaults = Dir.glob('C:/openstudio-2.*').sort.reverse
      end
    else
      if sketchup_version >= 19
        defaults = Dir.glob('/Applications/OpenStudioApplication-*').sort.reverse
      else
        defaults = ['/Applications/OpenStudio-2*']
      end
    end

    input = UI.inputbox(prompts, defaults, "Select OpenStudio Root Directory.")

    # check if user cancelled
    if input.is_a? FalseClass
      do_load = false
      break
    end

    openstudio_dir = input[0]
    openstudio_dir.gsub('\\', '/')

  end

  # see if we can find the openstudio ruby file
  key_file = nil
  if sketchup_version >= 19
    key_file = File.join(openstudio_dir, "Ruby/openstudio_modeleditor.rb")
  else
    key_file = File.join(openstudio_dir, "Ruby/openstudio.rb")
  end

  if File.exists?(key_file)
    Sketchup.write_default("OpenStudio", "OpenStudioDir", openstudio_dir)
    break
  else
    openstudio_dir = nil
  end

  UI.messagebox("File '#{key_file}' does not exist", MB_OK)
end

minimum_version = 17
maximum_version = 9999

if do_load
  begin
    if (sketchup_version < minimum_version || sketchup_version > maximum_version)
      UI.messagebox("OpenStudio #{OpenStudio::SKETCHUPPLUGIN_VERSION} is compatible with SketchUp 2017.\nThe installed version is 20#{sketchup_version}.  The plugin was not loaded.", MB_OK)
    elsif sketchup_version >= 19
      openstudio_modeleditor_rb = File.join(openstudio_dir, "Ruby/openstudio_modeleditor.rb")
      load(openstudio_modeleditor_rb)
      load("openstudio/lib/PluginManager.rb")
    else
      openstudio_rb = File.join(openstudio_dir, "Ruby/openstudio.rb")
      load(openstudio_rb)
      $OPENSTUDIO_APPLICATION_DIR = File.join(openstudio_dir, "bin")
      load("openstudio/lib/PluginManager.rb")
    end
  rescue LoadError => e
    UI.messagebox("Error loading OpenStudio SketchUp Plug-In:\n  #{e.message}", MB_OK)
  end
else
  UI.messagebox("User cancelled loading OpenStudio SketchUp Plug-In", MB_OK)
end
