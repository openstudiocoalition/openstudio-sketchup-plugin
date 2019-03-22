########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC, and other contributors. All rights reserved.
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

# check current settings
openstudio_dir = Sketchup.read_default("OpenStudio", "OpenStudioDir")

if openstudio_dir.nil? || !File.exists?(openstudio_dir)

  prompts = ["Path to openstudio.rb"]
  is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
  if is_windows
    if sketchup_version >= 19
      defaults = ['C:/openstudio3-2.7.2']
    else
      defaults = ['C:/openstudio-2.7.2']
    end
  else
    defaults = ['']
  end

  input = UI.inputbox(prompts, defaults, "Select OpenStudio Root Directory.")
  openstudio_dir = input[0]
  openstudio_dir.gsub('\\', '/')
  
  Sketchup.write_default("OpenStudio", "OpenStudioDir", openstudio_dir)
end

minimum_version = 17
maximum_version = 9999

begin
  if (sketchup_version < minimum_version || sketchup_version > maximum_version)
    UI.messagebox("OpenStudio #{$OPENSTUDIO_SKETCHUPPLUGIN_VERSION} is compatible with SketchUp 2017.\nThe installed version is 20#{sketchup_version}.  The plugin was not loaded.", MB_OK)
  else
    openstudio_rb = File.join(openstudio_dir, "Ruby/openstudio.rb")
    openstudio_modeleditor_rb = File.join(openstudio_dir, "Ruby/openstudio_modeleditor.rb")
    
    if File.exists?(openstudio_modeleditor_rb)
      load(openstudio_modeleditor_rb) if File.exists?(openstudio_modeleditor_rb)
    else
      load(openstudio_rb)
    end
    load("openstudio/lib/PluginManager.rb")
  end
rescue LoadError => e
  UI.messagebox("Error loading OpenStudio SketchUp Plug-In:\n  #{e.message}", MB_OK)
end

