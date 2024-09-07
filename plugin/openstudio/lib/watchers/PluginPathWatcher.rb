########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################


module OpenStudio

  if defined?(OpenStudio::Modeleditor::PathWatcher)
    OpenStudioPathWatcherClass = OpenStudio::Modeleditor::PathWatcher
  else
    OpenStudioPathWatcherClass = OpenStudio::PathWatcher
  end

  PluginPathWatcher = Class.new(OpenStudio::OpenStudioPathWatcherClass) do

    def initialize(model_interface, path)
      super(path)

      @model_interface = model_interface
    end

    def onPathChanged
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # ignore any further signals until we finish processing
      disable

      skp_model = @model_interface.skp_model

      if (not skp_model.valid?)

        Plugin.log(OpenStudio::Debug, "skp_model #{skp_model} is not valid, active model is #{Sketchup.active_model}")

        # skp_model is no longer valid (e.g. closed on Mac)
        proc = Proc.new { Plugin.model_manager.purge_invalid_model_interfaces }
        Plugin.add_event( proc )

        # continue ignoring

      elsif skp_model != Sketchup.active_model

        Plugin.log(OpenStudio::Debug, "skp_model #{skp_model} is not active_model, active model is #{Sketchup.active_model}")

        # no-op to avoid a crash when you try to update a model that is not the active model

        # re-enable the watcher
        enable

      else

        success = false
        result = UI.messagebox("Another application has updated #{self.path.to_s}, do you want to reload it?", MB_YESNO)
        if result == 6 # Yes
          success = Plugin.model_manager.open_openstudio(self.path.to_s, Sketchup.active_model)
        end

        if success
          # continue ignoring, new watcher will take over
        else
          # re-enable the watcher
          enable
        end
      end

    end

  end
end
