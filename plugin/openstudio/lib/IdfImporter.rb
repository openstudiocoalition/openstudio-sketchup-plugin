########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/ModelManager")


module OpenStudio

   class IdfImporter < Sketchup::Importer

     # This method is called by SketchUp to determine the description that
     # appears in the File > Import dialog's pulldown list of valid
     # importers.
     def description
       return "EnergyPlus Files (*.idf)"
     end

     # This method is called by SketchUp to determine what file extension
     # is associated with your importer.
     def file_extension
       return "idf"
     end

     # This method is called by SketchUp to get a unique importer id.
     def id
       return "com.sketchup.importers.idf"
     end

     # This method is called by SketchUp to determine if the "Options"
     # button inside the File > Import dialog should be enabled while your
     # importer is selected.
     def supports_options?
       return true
     end

     # This method is called by SketchUp when the user clicks on the
     # "Options" button inside the File > Import dialog. You can use it to
     # gather and store settings for your importer.
     def do_options
       # In a real use you would probably store this information in an
       # instance variable.
       prompts = ["Import Options"]
       defaults = ["Entire Model"]
       list = ["Entire Model|Constructions|Schedules"]
       @options = UI.inputbox(prompts, defaults, list, "Import Options.")
     end

     # This method is called by SketchUp after the user has selected a file
     # to import. This is where you do the real work of opening and
     # processing the file.
     def load_file(file_path, status)

       file_path.gsub!(/\\/, '/')

       Plugin.write_pref("Last Idf Import Dir", File.dirname(file_path))  # Save the dir so we can start here next time

       workspace = Plugin.model_manager.workspace_from_idf_path(file_path)
       if not workspace
         return(0)
       end

       if not @options
        @options = ["Entire Model"]
       end

       case @options[0]
       when "Entire Model"
         if (Plugin.command_manager.prompt_to_continue_import("EnergyPlus Idf"))
           openstudio_model, errors, warnings, untranslated_idf_objects = Plugin.model_manager.model_from_workspace(workspace)

           # import does not set path
           Plugin.model_manager.attach_openstudio_model(openstudio_model, Sketchup.active_model, nil, false, true, errors, warnings, untranslated_idf_objects)
         end
       when "Constructions"
         Plugin.model_manager.model_interface.import_idf_constructions(workspace)
       when "Schedules"
         Plugin.model_manager.model_interface.import_idf_schedules(workspace)
       end

       return 0 # 0 is the code for a successful import
     end
   end

   Sketchup.register_importer(IdfImporter.new)

end
