########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/DrawingInterface")
require("openstudio/lib/interfaces/ModelInterface")
require("openstudio/lib/observers/EntityObserver")

module OpenStudio

  class RenderingColor < DrawingInterface

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super
      @observer = EntityObserver.new(self)
    end

##### Begin override methods for the input object #####

    def self.model_object_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_object = Plugin.model_manager.model_interface.openstudio_model.getRenderingColor(handle)
      if not model_object.empty?
        model_object = model_object.get
      else
        puts "RenderingColor: model_object is empty for #{handle.class}, #{handle.to_s}, #{Plugin.model_manager.model_interface.openstudio_model}"
        model_object = nil
      end
      return model_object
    end

    def self.new_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = RenderingColor.new
      model_object = model_object_from_handle(handle)

      # check if have a color
      if model_object.getInt(2).empty?
        color = OpenStudio::Model::RenderingColor::randomColor
        model_object.setRenderingRedValue(color.red)
        model_object.setRenderingGreenValue(color.green)
        model_object.setRenderingBlueValue(color.blue)
      end

      drawing_interface.model_object = model_object
      model_object.drawing_interface = drawing_interface
      drawing_interface.add_watcher
      return(drawing_interface)
    end

    def create_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_watcher_enabled = @model_interface.model_watcher.disable
      @model_object = OpenStudio::Model::RenderingColor.new(@model_interface.openstudio_model)
      @model_interface.model_watcher.enable if model_watcher_enabled
      super
    end

    def check_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      return(super)
    end


    # Updates the ModelObject with new information from the SketchUp entity.
    def update_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super

      if (valid_entity?)

        # some changes are not real changes, just reference count changes
        # there is a real cost in updating model object here because model_interface.request_paint may be called
        # this can even cause other observers to be ignored while model is being painted
        real_change = ((@model_object.name.get != @entity.name) or
                       (@model_object.renderingRedValue.to_i != @entity.color.red.to_i) or
                       (@model_object.renderingGreenValue.to_i != @entity.color.green.to_i) or
                       (@model_object.renderingBlueValue.to_i != @entity.color.blue.to_i) or
                       (@model_object.renderingAlphaValue.to_i != (255*@entity.alpha).to_i))

        if not real_change
          Plugin.log(OpenStudio::Debug, "Ignoring change to RenderingColor " + @model_object.name.to_s)
          return
        end

        watcher_enabled = disable_watcher

        Plugin.log(OpenStudio::Debug, "Before update " + @model_object.to_s)

        if not @model_object.setName(@entity.name)
          Plugin.log(OpenStudio::Debug, "Failed to set OS:RenderingColor name to " + @entity.name)
        end

        self.color = @entity.color
        self.alpha = @entity.alpha

        Plugin.log(OpenStudio::Debug, "After update " + @model_object.to_s)

        enable_watcher if watcher_enabled

        # model_object changed, call paint here
        rendering_mode = @model_interface.materials_interface.rendering_mode
        if rendering_mode == RenderByConstruction or
           rendering_mode == RenderBySpaceType or
           rendering_mode == RenderByThermalZone or
           rendering_mode == RenderByBuildingStory
          @model_interface.request_paint
        end

      end
    end

    # Returns the parent drawing interface according to the input object.
    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return @model_interface
    end

##### Begin override methods for the entity #####

    def create_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      had_observers = remove_observers

      materials = @model_interface.skp_model.materials

      # add a new material
      @entity = materials.add(@model_object.name.get)
      @entity.color = color
      @entity.alpha = alpha

      add_observers if had_observers

    end


    # Updates the SketchUp entity with new information from the ModelObject.
    def update_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # do not want to call super if just want to redraw
      super

      if(valid_entity?)

        # do not want to trigger update_model_object in here
        had_observers = remove_observers

        name_changed = false
        begin
          @entity.name = @model_object.name.get
          name_changed = true
        rescue
        end

        if not name_changed
          if @model_object.name.get != @entity.name
            Plugin.log(OpenStudio::Debug, "Failed to set Material entity name to " + @model_object.name.get)
            Plugin.log(OpenStudio::Debug, "Setting RenderingColor model object name to " + @entity.name)

            had_watcher = disable_watcher
            @model_object.setName(@entity.name)
            add_watcher if had_watcher

            Plugin.dialog_manager.inspector_dialog.rebuildInspectorGadget(true) if Plugin.dialog_manager && Plugin.dialog_manager.inspector_dialog
          end
        end

        @entity.color = color
        @entity.alpha = alpha

        add_observers if had_observers

        # entity changed, already up to date, no need to paint

      end

    end

    # Final cleanup of the entity.
    # This method is called by the model interface after the entire input file is drawn.
    def cleanup_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super
    end

    # Returns the parent drawing interface according to the entity.
    def parent_from_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return @model_interface
    end

##### Begin override methods for the interface #####

    def add_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super(recursive) # takes care of @observer only, also handles recursive argument

      @model_interface.materials_interface.add_observers(false)
    end


    def remove_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      had_observers = super(recursive) # takes care of @observer only, also handles recursive argument

      @model_interface.materials_interface.remove_observers(false)

      return had_observers
    end

    def destroy_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = super(recursive) # takes care of @observer only, also handles recursive argument

      return result
    end


##### Begin new methods for the interface #####

    def color
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = Sketchup::Color.new(@model_object.renderingRedValue, @model_object.renderingGreenValue, @model_object.renderingBlueValue)

      return(result)
    end

    def color=(color)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @model_object.setRenderingRedValue(color.red)
      @model_object.setRenderingGreenValue(color.green)
      @model_object.setRenderingBlueValue(color.blue)
    end

    def alpha
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = @model_object.renderingAlphaValue / 255.0
      result = [0.0, result].max
      result = [result, 1.0].min

      return result
    end

    def alpha=(alpha)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      alpha = (255*alpha).to_i
      alpha = [0, alpha].max
      alpha = [alpha, 255].min

      @model_object.setRenderingAlphaValue( alpha )
    end

  end

end
