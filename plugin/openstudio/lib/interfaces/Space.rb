########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/SurfaceGroup")
require("openstudio/lib/watchers/RenderableModelObjectWatcher")


module OpenStudio

  class Space < SurfaceGroup

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super
    end

##### Begin override methods for the input object #####

    def self.model_object_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_object = Plugin.model_manager.model_interface.openstudio_model.getSpace(handle)
      if not model_object.empty?
        model_object = model_object.get
      else
        puts "Space: model_object is empty for #{handle.class}, #{handle.to_s}, #{Plugin.model_manager.model_interface.openstudio_model}"
        model_object = nil
      end
      return model_object
    end

    def self.new_from_handle(handle)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = Space.new
      model_object = model_object_from_handle(handle)
      drawing_interface.model_object = model_object
      model_object.drawing_interface = drawing_interface
      drawing_interface.add_watcher
      return(drawing_interface)
    end

    def create_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      model_watcher_enabled = @model_interface.model_watcher.disable
      @model_object = OpenStudio::Model::Space.new(@model_interface.openstudio_model)

      @model_interface.model_watcher.enable
      if Plugin.read_pref("New Zone for Space")
        if @model_object.thermalZone.empty?
          thermal_zone = OpenStudio::Model::ThermalZone.new(@model_interface.openstudio_model)
          @model_object.setThermalZone(thermal_zone)
        end
      end

      @model_interface.model_watcher.disable if not model_watcher_enabled

      super
    end


    # The parent interface is the model interface.
    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      return @model_interface.building
    end


##### Begin override methods for the entity #####


    # Final cleanup of the entity.
    # This method is called by the model interface after the entire input file is drawn.
    #
    # For spaces, check for any problems with its faces.
    def cleanup_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super

      if @entity.deleted?
        # how did this happen?
        return nil
      end

      faces = @entity.entities.find_all { |this_entity| this_entity.is_a? Sketchup::Face }

      for face in faces
        # Check for any faces that were somehow added and did not get a drawing interface (should never happen).
        if (OpenStudio.get_drawing_interface(face).nil?)
          puts "Space.cleanup_entity:  missing a drawing interface for " + face.to_s
        else

          # Check for any swaps that got under the radar.
          # THIS SHOULD NEVER HAPPEN!  THIS IS NOW BEING TRAPPED BY EACH SURFACE AS IT IS CREATED.
          # THIS PASS SHOULD BE COMPLETELY REDUNDANT.
          # This can happen when the SketchUp 'add_face' method adds two faces when only one was specified (see below).
          if (OpenStudio.get_drawing_interface(face).entity != face)
            puts "Space.cleanup_entity:  unhandled swap for " + face.to_s

            # Fix the swap--surprisingly this seems to be sufficient.
            OpenStudio.get_drawing_interface(face).entity = face
          end
        end
      end


      # THIS CAN PROBABLY BE MOVED INTO THE 'CLEANUP_ENTITY' METHOD OF THE DRAWINGINTERFACE FOR SURFACE
      for face in faces
        # Check for any faces with duplicate drawing interfaces
        for other_face in faces

          next if (not face.valid? or not other_face.valid?)
          next if (face.area == 0 or other_face.area == 0)

          if (OpenStudio.get_drawing_interface(other_face) == OpenStudio.get_drawing_interface(face) and other_face != face)
            puts "Space.cleanup_entity:  duplicate drawing interface for " + face.to_s + ", " + other_face.to_s

            # Occasionally the SketchUp 'add_face' method will (accidentally?) add two faces when only one was specified.
            # Usually there is some inferred behavior about the base face that leads to one version of the new face being drawn.
            # Meanwhile another version of the new face is also drawn that more accurately matches the vertices that were input.
            # The result is two faces that are coincident yet different.  The new face that is carved out of the base face
            # inherits its drawing interface--this is the duplicate face.

            # Try to find the correct faces and delete the extra one
            # The two coincident faces will have the same reduced outer polygon.

            # Only one of the duplicates ('face' or 'other_face') will match exactly one other face.

            # Try to find a match for 'face'
            found = false
            for test_face in faces
              next if (not test_face.valid?)

              test_face_points = OpenStudio.get_outer_polygon(test_face).reduce.points
              face_points = OpenStudio.get_outer_polygon(face).reduce.points

              if (test_face != face and OpenStudio.is_same_set?(test_face_points, face_points))
                intended_face = test_face
                inferred_face = face
                found = true
              end
            end

            # Try to find a match for 'other_face'
            if (not found)
              for test_face in faces
                next if (not test_face.valid?)

                test_face_points = OpenStudio.get_outer_polygon(test_face).reduce.points
                other_face_points = OpenStudio.get_outer_polygon(other_face).reduce.points

                if (test_face != other_face and OpenStudio.is_same_set?(test_face_points, other_face_points))
                  #puts "matched other face: " + test_face.to_s + ", " + face.to_s
                  intended_face = test_face
                  inferred_face = other_face
                  found = true
                end
              end
            end

            # 'intended_face' should be the sub face, the one we really wanted in the first place
            # 'inferred_face' should be the one that was added when the API tried to infer (incorrectly) what to do


            if (found)
              # Fix the faces
              # The 'intended_face' has the wrong geometry (not connected to base face properly) but the correct drawing interface.
              # The 'inferred_face' has the correct geometry, but the wrong drawing interface.

              #puts "intended" + intended_face.to_s + " " + intended_face.vertices.length.to_s
              #puts "inferred" + inferred_face.to_s + " " + inferred_face.vertices.length.to_s

              drawing_interface = OpenStudio.get_drawing_interface(intended_face)
              OpenStudio.set_drawing_interface(inferred_face, drawing_interface)
              drawing_interface.entity = inferred_face
              drawing_interface.surface_polygon = drawing_interface.face_polygon
              drawing_interface.paint_entity

              @entity.entities.erase_entities(intended_face)

            else
              # This can happen if a face was unintentionally subdivided when another face was drawn.
              #puts "Could not find a coincident face for the duplicate--will create new object"

              if (OpenStudio.get_drawing_interface(other_face).is_a? Surface)
                new_surface = Surface.new_from_entity(other_face)

              elsif (OpenStudio.get_drawing_interface(other_face).is_a? SubSurface)
                new_surface = SubSurface.new_from_entity(other_face)

              else # attached shading, detached shading
                #puts "need to add new objects for shading surfaces!"

              end

              @model_interface.add_error("Warning:  A surface was subdivided because of connected geometry.\n")
              @model_interface.add_error("Added new surface " + new_surface.name + "\n")
              @model_interface.add_error("You should check your geometry carefully for mistakes.\n\n")
            end
          end
        end
      end

    end


##### Begin override methods for the interface #####

    def add_watcher
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (@model_object)
        @watcher = RenderableModelObjectWatcher.new(self, self, [2, 3, 9, 10], [RenderBySpaceType, RenderByConstruction, RenderByBuildingStory, RenderByThermalZone])
      end
    end

    def set_entity_name
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @entity.name = "Space:  " + @model_object.name.get
    end

##### Begin new methods for the interface #####

  end

end
