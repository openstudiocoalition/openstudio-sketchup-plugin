########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/DrawingInterface")


module OpenStudio

  class ConstructionBase < DrawingInterface

    def self.model_object_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_object = Plugin.model_manager.model_interface.openstudio_model.getConstructionBase(handle)
      if not model_object.empty? and (handle.to_s == model_object.get.handle.to_s)
        model_object = model_object.get
      else
        puts "ConstructionBase: model_object is empty for #{handle.class}, #{handle.to_s}, #{Plugin.model_manager.model_interface.openstudio_model}"
        model_object = nil
      end
      return model_object
    end

    def self.new_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = ConstructionBase.new
      model_object = model_object_from_handle(handle)
      drawing_interface.model_object = model_object
      model_object.drawing_interface = drawing_interface
      drawing_interface.add_watcher
      return(drawing_interface)
    end


    def create_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_watcher_enabled = @model_interface.model_watcher.disable
      @model_object = OpenStudio::Model::Construction.new(@model_interface.openstudio_model)
      @model_interface.model_watcher.enabled if model_watcher_enabled

      # no entity, nothing to do
      #super
    end


    def check_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (super)
        if @model_object.renderingColor.empty?
          watcher_enabled = disable_watcher
          model_watcher_enabled = @model_interface.model_watcher.disable
          had_observers = @model_interface.materials_interface.remove_observers

          rendering_color = OpenStudio::Model::RenderingColor.new(@model_interface.openstudio_model)
          @model_object.setRenderingColor(rendering_color)
          @model_interface.model_watcher.onObjectAdd(rendering_color)

          @model_interface.materials_interface.add_observers if had_observers
          @model_interface.model_watcher.enable if model_watcher_enabled
          enable_watcher if watcher_enabled
        end

        return(true)
      else
        return(false)
      end
    end

    # Updates the ModelObject with new information from the SketchUp entity.
    def update_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # should never be called, class does not have an entity
      #super
    end


    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return @model_interface
    end


    # There is no entity to create
    def create_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @entity = nil
    end

    def check_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return(false)
    end

    def confirm_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return(false)
    end

    # Updates the SketchUp entity with new information from the ModelObject.
    def update_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # model_object changed, call paint here
      if @model_interface.materials_interface.rendering_mode == RenderByConstruction
        @model_interface.request_paint
      end

    end


    def on_change_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    end


    def parent_from_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return @model_interface
    end

  end

end
