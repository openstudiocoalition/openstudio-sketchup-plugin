########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class AppObserver < Sketchup::AppObserver

    # cannot enable/disable this class

    # onNewModel get called when the 'New' menu item is clicked, even though the user clicks cancel!  Very strange.
    # The active_model object reference is even changed as well, although none of the content of the model changes...
    # onOpenModel has the same behavior.
    # The work-around is to save and compare the 'guid' which does not change unless a truly new model is created or opened.

    def onNewModel(model)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if Plugin.model_manager.model_interface and
         Plugin.model_manager.model_interface.skp_model_guid == model.guid

        # same model, no-op
        Plugin.log(OpenStudio::Trace, "New model is the same as current model")
      else

        Plugin.model_manager.new_from_skp_model(model)

        Plugin.menu_manager.refresh

        Plugin.model_manager.purge_invalid_model_interfaces
      end

    end

    def onOpenModel(model)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      Plugin.model_manager.new_from_skp_model(model)

      Plugin.menu_manager.refresh

      Plugin.model_manager.purge_invalid_model_interfaces
    end

    # Note:  Sketchup.active_model is already nil at this point
    def onQuit
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      Plugin.model_manager.shutdown
    end


    #def onUnloadExtension
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #end

  end

end
