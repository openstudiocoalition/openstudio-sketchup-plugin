########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require 'extensions.rb'   # defines the SketchupExtension class
require 'rbconfig'

module OpenStudio
  SKETCHUPPLUGIN_NAME = "OpenStudio"
  SKETCHUPPLUGIN_VERSION = "1.8.0"
  SKETCHUPPLUGIN_LAUNCH_GETTING_STARTED_ON_START = false
end

ext = SketchupExtension.new("OpenStudio", "OpenStudio/Startup")
ext.name = OpenStudio::SKETCHUPPLUGIN_NAME
ext.description = "Adds building energy modeling capabilities by coupling SketchUp to the OpenStudio suite of tools.  \r\n\r\nVisit openstudio.net for more information."
ext.version = OpenStudio::SKETCHUPPLUGIN_VERSION
ext.creator = "OpenStudio Coalition"
ext.copyright = "OpenStudio Coalition and other contributors."

# 'true' automatically loads the extension the first time it is registered, e.g., after install
Sketchup.register_extension(ext, true)


