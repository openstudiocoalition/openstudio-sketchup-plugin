########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/PlanarSurface")
require("openstudio/lib/interfaces/ShadingSurfaceGroup")

module OpenStudio

  class ShadingSurface < PlanarSurface

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super
      @container_class = ShadingSurfaceGroup
    end

##### Begin methods for the input object #####

    def self.model_object_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_object = Plugin.model_manager.model_interface.openstudio_model.getShadingSurface(handle)
      if not model_object.empty?
        model_object = model_object.get
      else
        puts "ShadingSurface: model_object is empty for #{handle.class}, #{handle.to_s}, #{Plugin.model_manager.model_interface.openstudio_model}"
        model_object = nil
      end
      return model_object
    end

    def self.new_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = ShadingSurface.new
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
        @model_object = OpenStudio::Model::ShadingSurface.new(vertices, @model_interface.openstudio_model)
        @model_interface.model_watcher.enable if model_watcher_enabled
      rescue RuntimeError => error
        Plugin.log(Error, "Could not create ShadingSurface for vertices #{vertices}")
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
        if (@parent.is_a? ShadingSurfaceGroup)
          watcher_enabled = disable_watcher

          @model_object.setShadingSurfaceGroup(@parent.model_object)

          enable_watcher if watcher_enabled
        end
      end
    end


    # Returns the parent drawing interface according to the input object.
    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      parent = nil
      if (@model_object)
        shadingGroup = @model_object.shadingSurfaceGroup

        if (not shadingGroup.empty?)
          parent = shadingGroup.get.drawing_interface
        end
      end
      return(parent)
    end



##### Begin methods for the entity #####


##### Begin override methods for the interface #####


    def in_selection?(selection)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if @parent.parent
        return (selection.contains?(@entity) or selection.contains?(@parent.entity) or selection.contains?(@parent.parent.entity))
      else
        return (selection.contains?(@entity) or selection.contains?(@parent.entity))
      end
    end

    def paint_surface_type(info=nil)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      shading_surface_type = @parent.shading_surface_type.upcase
      if (shading_surface_type == "SITE")
        @entity.material = @model_interface.materials_interface.site_shading
        @entity.back_material = @model_interface.materials_interface.site_shading_back
      elsif (shading_surface_type == "BUILDING")
        @entity.material = @model_interface.materials_interface.building_shading
        @entity.back_material = @model_interface.materials_interface.building_shading_back
      elsif (shading_surface_type == "SPACE")
        @entity.material = @model_interface.materials_interface.space_shading
        @entity.back_material = @model_interface.materials_interface.space_shading_back
      end

      if @model_object.solarCollectors.size > 0
        @entity.material = @model_interface.materials_interface.solar_collector
      elsif @model_object.generatorPhotovoltaics.size > 0
        @entity.material = @model_interface.materials_interface.photovoltaic
      end
    end


##### Begin new methods for the interface #####

  end

end
