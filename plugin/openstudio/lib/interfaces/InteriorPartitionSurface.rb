########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/PlanarSurface")
require("openstudio/lib/interfaces/InteriorPartitionSurfaceGroup")

module OpenStudio

  class InteriorPartitionSurface < PlanarSurface

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super
      @container_class = InteriorPartitionSurfaceGroup
    end

##### Begin methods for the input object #####

    def self.model_object_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_object = Plugin.model_manager.model_interface.openstudio_model.getInteriorPartitionSurface(handle)
      if not model_object.empty?
        model_object = model_object.get
      else
        puts "InteriorPartitionSurface: model_object is empty for #{handle.class}, #{handle.to_s}, #{Plugin.model_manager.model_interface.openstudio_model}"
        model_object = nil
      end
      return model_object
    end

    def self.new_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = InteriorPartitionSurface.new
      model_object = model_object_from_handle(handle)
      drawing_interface.model_object = model_object
      model_object.drawing_interface = drawing_interface
      drawing_interface.add_watcher
      return(drawing_interface)
    end

    def create_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      # need to get parents transformation
      update_parent_from_entity

      model_watcher_enabled = @model_interface.model_watcher.disable
      vertices = vertices_from_polygon(face_polygon)

      begin
        @model_object = OpenStudio::Model::InteriorPartitionSurface.new(vertices, @model_interface.openstudio_model)
        @model_interface.model_watcher.enable if model_watcher_enabled
      rescue RuntimeError => error
        Plugin.log(Error, "Could not create InteriorPartitionSurface for vertices #{vertices}")
        return nil
      end

      super
    end

    def check_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (super)
        # Check for coincident surfaces (check other surfaces in group)
        return(true)
      else
        return(false)
      end
    end

    # Updates the ModelObject with new information from the SketchUp entity.
    def update_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super  # PlanarSurface superclass updates the vertices

      if (valid_entity?)
        if (@parent.is_a? InteriorPartitionSurfaceGroup)
          watcher_enabled = disable_watcher

          @model_object.setInteriorPartitionSurfaceGroup(@parent.model_object)  # Parent should already have been updated.

          enable_watcher if watcher_enabled
        end
      end
    end


    # Returns the parent drawing interface according to the input object.
    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      parent = nil
      if (@model_object)
        interiorPartitionSurfaceGroup = @model_object.interiorPartitionSurfaceGroup
        if (not interiorPartitionSurfaceGroup.empty?)
          parent = interiorPartitionSurfaceGroup.get.drawing_interface
        end
      end
      return(parent)
    end



##### Begin methods for the entity #####


##### Begin override methods for the interface #####


    def in_selection?(selection)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return (selection.contains?(@entity) or selection.contains?(@parent.entity) or selection.contains?(@parent.parent.entity))
    end

    def paint_surface_type(info=nil)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @entity.material = @model_interface.materials_interface.interior_partition_surface
      @entity.back_material = @model_interface.materials_interface.interior_partition_surface_back
    end


##### Begin new methods for the interface #####

  end

end
