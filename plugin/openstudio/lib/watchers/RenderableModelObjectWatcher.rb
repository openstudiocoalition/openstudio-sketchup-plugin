########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/watchers/PluginModelObjectWatcher")

module OpenStudio

  class RenderableModelObjectWatcher < PluginModelObjectWatcher

    def initialize(drawing_interface, interface_to_paint, rendering_indices, rendering_modes)
      super(drawing_interface)

      @interface_to_paint = interface_to_paint
      @rendering_indices = rendering_indices
      @rendering_modes = rendering_modes
    end

    #def onChangeIdfObject
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def onDataFieldChange
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def onNameChange
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def onBecomeDirty
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def onBecomeClean
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def clearState
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    def onRelationshipChange(index, newHandle, oldHandle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      if i = @rendering_indices.index(index)
        if @drawing_interface.model_interface.materials_interface.rendering_mode == @rendering_modes[i]
          @interface_to_paint.request_paint
        end
      end
    end

    #def onRemoveFromWorkspace(handle)
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

  end
end

