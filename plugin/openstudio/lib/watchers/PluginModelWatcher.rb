########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class PluginModelWatcher < WorkspaceWatcher

    def initialize(model_interface)
      super(model_interface.openstudio_model)

      @model_interface = model_interface

      @added_object_handles = []
    end

    #def clearState
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #  super
    #end

    #def onChangeWorkspace
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

    def onObjectAdd(addedObject)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      # wrapper object is not fully constructed yet, just store the handle
      @added_object_handles << addedObject.handle
    end

    def processAddedObjects
      if @added_object_handles.empty?
        return
      end

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      openstudio_model = @model_interface.openstudio_model

      # loop over all loaded objects
      @added_object_handles.each do |added_object_handle|

        model_object = openstudio_model.getObject(added_object_handle)

        if model_object.empty?
          Plugin.log(OpenStudio::Warn, "Can't find added object by handle = #{added_object_handle}")
        else
          addedObject = model_object.get

          @model_interface.on_new_model_object(addedObject)

          class_name = addedObject.iddObject.name.upcase

          # these objects do not have a drawing interface where we can call check_model_object
          if class_name == "OS:ELECTRICEQUIPMENT" or
             class_name == "OS:GASEQUIPMENT" or
             class_name == "OS:HOTWATEREQUIPMENT" or
             class_name == "OS:INTERNALMASS" or
             class_name == "OS:LIGHTS" or
             class_name == "OS:LUMINAIRE" or  # should not ever get luminaire
             class_name == "OS:PEOPLE"

            spaceLoadInstance = addedObject.to_SpaceLoadInstance

            OpenStudio::Modeleditor::ensureSpaceLoadDefinition(spaceLoadInstance.get)

          end

        end
      end

      @added_object_handles.clear

    end

    # this is called before the object has been removed
    def onObjectRemove(removedObject)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      if drawing_interface = removedObject.drawing_interface
        drawing_interface.on_pre_delete_model_object
      end
    end

  end

end

