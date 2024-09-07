########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/ModelManager")


module OpenStudio

   class GbXMLImporter < Sketchup::Importer

     # This method is called by SketchUp to determine the description that
     # appears in the File > Import dialog's pulldown list of valid
     # importers.
     def description
       return "Green Building XML (*.xml)"
     end

     # This method is called by SketchUp to determine what file extension
     # is associated with your importer.
     def file_extension
       return "xml"
     end

     # This method is called by SketchUp to get a unique importer id.
     def id
       return "com.sketchup.importers.gbXML"
     end

     # This method is called by SketchUp to determine if the "Options"
     # button inside the File > Import dialog should be enabled while your
     # importer is selected.
     def supports_options?
       return false
     end

     # This method is called by SketchUp when the user clicks on the
     # "Options" button inside the File > Import dialog. You can use it to
     # gather and store settings for your importer.
     def do_options
       # In a real use you would probably store this information in an
       # instance variable.
       #prompts = ["Import Options"]
       #defaults = ["Entire Model"]
       #list = ["Entire Model|Constructions|Schedules"]
       #@options = UI.inputbox(prompts, defaults, list, "Import Options.")
     end

     # This method is called by SketchUp after the user has selected a file
     # to import. This is where you do the real work of opening and
     # processing the file.
     def load_file(file_path, status)

       file_path.gsub!(/\\/, '/')

       Plugin.write_pref("Last gbXML Import Dir", File.dirname(file_path))  # Save the dir so we can start here next time

       openstudio_model, errors, warnings = Plugin.model_manager.model_from_gbXML_path(file_path)
       if not openstudio_model
         return(0)
       end

       if (Plugin.command_manager.prompt_to_continue_import("Green Building XML"))
         Plugin.model_manager.attach_openstudio_model(openstudio_model, Sketchup.active_model, nil, false, true, errors, warnings)
       end

       return 0 # 0 is the code for a successful import
     end
   end

   Sketchup.register_importer(GbXMLImporter.new)

end
