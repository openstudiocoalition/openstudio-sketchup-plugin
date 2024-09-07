########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require 'extensions.rb'   # defines the SketchupExtension class

sketchup_version = Sketchup.version.split('.').first.to_i
do_load = true

# check current settings
openstudio_dir = Sketchup.read_default("OpenStudio", "OpenStudioDir")

while true

  if openstudio_dir.nil? || !File.exist?(openstudio_dir)

    prompts = ["Path to OpenStudio Root Directory"]
    is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
    base_dir = nil
    if is_windows
      if sketchup_version >= 19
        base_dir = 'C:/openstudioapplication-*'
      else
        base_dir = 'C:/openstudio-2.*'
      end
    else
      if sketchup_version >= 19
        base_dir = '/Applications/OpenStudioApplication-*'
      else
        base_dir = '/Applications/OpenStudio-2*'
      end
    end

    defaults = Dir.glob(base_dir).sort.reverse
    if sketchup_version >= 19
      defaults.reject! do |file|
        if md = /openstudioapplication-(\d+)\.(\d+)/i.match(file)
          if sketchup_version >= 24
            # SketchUp 2024 requires OpenStudio Application 1.8.0 or higher
            md[1].to_i == 1 and md[2].to_i < 8
          else
            # SketchUp 2019-2023 requires OpenStudio Application 1.7.0 or lower
            md[1].to_i > 1 or md[2].to_i > 7
          end
        else
          true
        end
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

  if File.exist?(key_file)
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
    Sketchup.write_default("OpenStudio", "OpenStudioDir", nil)

    result = UI.messagebox("Error loading OpenStudio SketchUp Plug-In:\n  #{e.message}\n\nDo you want to check the version compatibility matrix?", MB_YESNO)
    if result == IDYES
      UI.openURL("https://github.com/openstudiocoalition/openstudio-sketchup-plugin/wiki/OpenStudio-SketchUp-Plug-in-Wiki#openstudio-sketchup-plug-in-version-compatibility-matrix")
    end
  end
else
  UI.messagebox("User cancelled loading OpenStudio SketchUp Plug-In", MB_OK)
end
