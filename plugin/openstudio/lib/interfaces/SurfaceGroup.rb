########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/DrawingInterface")
require("openstudio/lib/observers/InstanceObserver")
require("openstudio/lib/observers/SurfaceGroupObserver")
require("openstudio/lib/observers/SurfaceGroupEntitiesObserver")


module OpenStudio

  class SurfaceGroup < DrawingInterface

    attr_accessor :instance_observer, :entities_observer

    def initialize
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super
      @observer = SurfaceGroupObserver.new(self)
      @instance_observer = InstanceObserver.new(self)  # get onOpen and onClose callbacks for the Group.
      @entities_observer = SurfaceGroupEntitiesObserver.new(self)
      @instance_observer_added = false # true if observer has been added to the entity
    end


##### Begin override methods for the input object #####

    # Updates the ModelObject with new information from the SketchUp entity.
    def update_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      if (valid_entity?)

        watcher_enabled = disable_watcher

        # set the transfomation
#puts "update_model_object, self.coordinate_transformation = #{self.coordinate_transformation.to_a.join(',')}"
#puts "update_model_object, @entity.transformation = #{@entity.transformation.to_a.join(',')}"
        transformation = OpenStudio::transformation_to_openstudio(self.coordinate_transformation)
#puts "update_model_object, transformation = #{transformation.to_a.join(',')}"
        if not @model_object.setTransformation(transformation)
          # reject the changes and go back to ModelObject's origin and rotation
          puts "Surface group cannot be rotated about any axis other than z"
          update_entity(false)
        end

        # All enclosed entities must be transformed.
        update_child_model_objects

        enable_watcher if watcher_enabled
      end
#puts "********************"
    end

    def update_child_model_objects
      if @entity.is_a? Sketchup::Group
        for entity in @entity.entities
          if (OpenStudio.get_drawing_interface(entity))
            OpenStudio.get_drawing_interface(entity).update_model_object
          end
        end
      end
    end


    # Override in sub classes
    def parent_from_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      return(nil)
    end

    # Called by the model object watcher
    def on_change_model_object
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      # to_a seems to be important here, maybe because it dup's the objects
      for child in @children
        child.on_change_model_object
      end
    end

##### Begin override methods for the entity #####

    # Updates the SketchUp entity with new information from the ModelObject.
    def update_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      if (valid_entity?)

        # do not want to trigger update_model_object in here
        had_observers = remove_observers

        set_entity_name
#puts "update_entity, @model_object.transformation = #{@model_object.transformation.to_a}"
#puts "update_entity, @entity.transformation = #{@entity.transformation.to_a.join(',')}"
#puts "update_entity, self.coordinate_transformation = #{self.coordinate_transformation.to_a.join(',')}"
        self.coordinate_transformation = OpenStudio::transformation_from_openstudio(@model_object.transformation)
#puts "update_entity, @entity.transformation = #{@entity.transformation.to_a.join(',')}"
#puts "********************"

        # update children
        update_child_entities

        add_observers if had_observers
      end
    end

    def update_child_entities
      @entity.entities.each do |entity|
        if drawing_interface = OpenStudio.get_drawing_interface(entity)
          drawing_interface.update_parent_from_entity
          drawing_interface.update_entity
        end
      end
    end

    #def paint_entity(info = nil)
    #  # do not want to trigger update_model_object in here
    #  had_observers = remove_observers
    #
    #  # find if have visible children
    #  has_child_interface = false
    #  @entity.entities.each do |entity|
    #    if drawing_interface = OpenStudio.get_drawing_interface(entity)
    #      has_child_interface = true
    #      break
    #    end
    #  end
    #
    #  if has_child_interface
    #    if @cpoint2
    #      if not @cpoint2.deleted?
    #        @entity.entities.erase_entities(@cpoint2)
    #        @cpoint2 = nil
    #      end
    #    end
    #  else
    #    #if not @cpoint2
    #    #  @cpoint2 = @entity.entities.add_cpoint(Geom::Point3d.new(5.m, 5.m, 3.m))
    #    #  @cpoint2.hidden = true
    #    #end
    #  end
    #
    #  add_observers if had_observers
    #end

    def create_from_entity_copy(entity)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      had_observers = remove_observers

      # function call says deprecated but this is still needed as of SU8
      entity.make_unique

      # Copy all of the Group child interfaces.
      # (OR could recurse the children of this SurfaceGroup interface.)
      for child_entity in entity.entities
        if (OpenStudio.get_drawing_interface(child_entity))
          original_interface = OpenStudio.get_drawing_interface(child_entity)
          original_class = original_interface.class

          drawing_interface = original_class.new_from_entity_copy(child_entity)

          OpenStudio.set_drawing_interface(child_entity, drawing_interface)
          drawing_interface.entity = child_entity
        end
      end

      on_change_entity  # Necessary because the order of copying the child entities may not have updated all the parent references correctly.
      add_observers if had_observers

      return(self)
    end

    def create_initial_box(path)
      definition = Sketchup.active_model.definitions.load(path)
      @initial_box = @entity.entities.add_instance(definition, Geom::Transformation.new)
      #@initial_box.make_unique
    end

    def delete_initial_box
      # do not want to trigger update_model_object in here
      had_observers = remove_observers

      if @initial_box
        if not @initial_box.deleted?
          @entity.entities.erase_entities(@initial_box)
          @initial_box = nil
        end
      end

      add_observers if had_observers
    end

    def create_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (@parent.nil?)
        # how did this happen?
        Plugin.log(OpenStudio::Error, "Parent #{@parent} is nil, cannot create entity for #{@model_object.name}")
        return nil
      end

      if @parent.is_a? Space
        @entity = @parent.entity.entities.add_group
      else
        @entity = Sketchup.active_model.entities.add_group
      end

      # set the name
      set_entity_name

#puts "create_entity, @entity.transformation = #{@entity.transformation.to_a.join(',')}"
#puts "create_entity, self.coordinate_transformation. = #{self.coordinate_transformation.to_a.join(',')}"
      self.coordinate_transformation = OpenStudio::transformation_from_openstudio(@model_object.transformation)
#puts "create_entity, @entity.transformation = #{@entity.transformation.to_a.join(',')}"
#puts "********************"

      # There was warning here that construction point cannot be drawn at 0, 0, 0 but
      # I have not experienced problems with that

      # WARNING:  From the Edit menu, the Delete Guides option will delete all construction points.
      # If a space is still empty at that time, the space will be deleted as well!
      @cpoint1 = @entity.entities.add_cpoint(Geom::Point3d.new(0.m, 0.m, 0.m))
      @cpoint1.hidden = false

      # create or confirm layer for class"
      model = Sketchup.active_model
      layers = model.layers
      new_layer = layers.add "#{@model_object.class}"
      # put entity onto new layer
      @entity.layer = new_layer
    end


    # Error checks and cleanup before an entity is accepted by the interface.
    # Return false if the entity cannot be used.
    def check_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (super)
        if (@entity.is_a? Sketchup::Group)
          return(true)
        else
          puts "SurfaceGroup.check_entity:  wrong class of entity"
          return(false)
        end
      else
        return(false)
      end
    end


    # Error checks, finalization, or cleanup needed after the entity is drawn.
    def confirm_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if (super)
        return(true)
      else
        return(false)
      end
    end


    # Final cleanup of the entity.
    # This method is called by the model interface after the entire input file is drawn.
    #
    # For SurfaceGroups, cleanup any leftover orphan edges that might remain after some faces were deleted.
    # If anyone wants the edges to persist, this could be a user preference.
    def cleanup_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super

      if @entity.deleted?
      # how did this happen?
        return nil
      end

      orphan_edges = []
      for this_entity in @entity.entities
        if (this_entity.is_a? Sketchup::Edge)
          if (this_entity.faces.empty?)
            # Be careful: looks like calling edge.find_faces will make edge.faces become non-empty
            orphan_edges << this_entity
          end
        end
      end
      @entity.entities.erase_entities(orphan_edges)
    end


    def clean_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super
      @entity.name = @model_object.name.to_s
    end

    def parent_from_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      parent = nil
      if @entity.parent.is_a?(Sketchup::Model)
        # space or shading group
        parent = @model_interface.building
      else
        # space shading or interior partition
        parent = OpenStudio.get_drawing_interface(@entity.parent.instances[0])
      end
      return(parent)
    end

    def containing_entity
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = nil
      if @entity.parent.is_a?(Sketchup::Model)
        # space or shading group
        result = @model_interface.skp_model
      else
        # space shading or interior partition
        result = @entity.parent.instances.first
      end
      return(result)
    end

    # Undelete happens when an entity is restored after an Undo event.
    def on_undelete_entity(entity)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
      super

      had_observers = remove_observers

      # Undelete all of the child interfaces.
      for child_entity in entity.entities
        if (OpenStudio.get_drawing_interface(child_entity))
          OpenStudio.get_drawing_interface(child_entity).on_undelete_entity(child_entity)
        end
      end

      add_observers if had_observers
    end


##### Begin override methods for the interface #####

    def add_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      super(recursive) # takes care of @observer only, also handles recursive argument

      if (valid_entity?)
        if Plugin.disable_observers
          if not @instance_observer_added
            @entity.add_observer(@instance_observer)
            @entity.entities.add_observer(@entities_observer)
            @instance_observer_added = true
          end
          @instance_observer.enable
          @entities_observer.enable
        else
          @entity.add_observer(@instance_observer)
          @entity.entities.add_observer(@entities_observer)
          @instance_observer_added = true
          @instance_observer.enable
          @entities_observer.enable
        end
      end
    end

    def remove_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      had_observers = super(recursive) # takes care of @observer only, also handles recursive argument

      if (valid_entity?)
        if Plugin.disable_observers
          if @instance_observer_added
            @instance_observer.disable
            @entities_observer.disable
          end
        else
          @entity.remove_observer(@instance_observer)
          @entity.entities.remove_observer(@entities_observer)
          @instance_observer.disable
          @entities_observer.disable
          @instance_observer_added = false
        end
      end

      return had_observers
    end

    def destroy_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = super(recursive) # takes care of @observer only, also handles recursive argument

      if @instance_observer
        if (valid_entity?)
          if Plugin.disable_observers
            # actually do remove here
            @entity.remove_observer(@instance_observer)
            @entity.entities.remove_observer(@entities_observer)
            @instance_observer.disable
            @entities_observer.disable
            @instance_observer_added = false
          else
            @entity.remove_observer(@instance_observer)
            @entity.entities.remove_observer(@entities_observer)
            @instance_observer.disable
            @entities_observer.disable
            @instance_observer_added = false
          end
        end

        @instance_observer.destroy
        @instance_observer = nil
        @entities_observer.destroy
        @entities_observer = nil
      end

      return result
    end

##### Begin new methods for the interface #####

    # override in subclasses
    def set_entity_name
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    end

  end

end
