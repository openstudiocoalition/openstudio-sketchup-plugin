########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/observers/SelectionObserver.rb")

module OpenStudio

  class SelectionInterface

    # for debugging
    attr_reader :model_interface, :observer, :selection

    def initialize(model_interface)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @model_interface = model_interface
      @selection = @model_interface.skp_model.selection

      @observer = SelectionObserver.new(self)
      @observer_added = false # true if observer has been added to the entity
    end

    def destroy
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @model_interface = nil
      @selection = nil
      @observer = nil
    end

    def add_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      if Plugin.disable_observers
        if not @observer_added
          @selection.add_observer(@observer)
          @observer_added = true
        end
        @observer.enable
      else
        @selection.add_observer(@observer)
        @observer_added = true
        @observer.enable
      end
    end

    def remove_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      had_observers = false
      if Plugin.disable_observers
        if @observer_added
          had_observers = @observer.disable
        end
      else
        had_observers = @selection.remove_observer(@observer)
        @observer.disable
        @observer_added = false
      end

      return had_observers
    end

    def destroy_observers(recursive = false)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      result = false
      if @observer
        if Plugin.disable_observers
          # actually do remove here
          @selection.remove_observer(@observer)
          @observer.disable
          @observer_added = false
        else
          @selection.remove_observer(@observer)
          @observer.disable
          @observer_added = false
        end
        @observer.destroy
        @observer = nil
        result = true
      end

      return result
    end

    # gets the drawing_interface which is actually selected, not render mode aware
    # render mode is applied in DialogManager::selection_changed
    def selected_drawing_interface
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      drawing_interface = nil
      if (@selection.empty?)
        Plugin.log(OpenStudio::Debug, "selection is empty")

        parent = @model_interface.skp_model.active_entities.parent
        if (parent.is_a? Sketchup::ComponentDefinition)
          # Gets the SurfaceGroup interface that is currently open for editing
          drawing_interface = OpenStudio.get_drawing_interface(parent.instances.first)

          Plugin.log(OpenStudio::Debug, "selected_drawing_interface = #{drawing_interface}")
        else
          drawing_interface = @model_interface.building

          Plugin.log(OpenStudio::Debug, "selected_drawing_interface = #{drawing_interface}")
        end

      else
        @selection.each do |entity|
          if (OpenStudio.get_drawing_interface(entity) and not OpenStudio.get_drawing_interface(entity).deleted? and (entity.is_a? Sketchup::Group or entity.is_a? Sketchup::Face or entity.is_a? Sketchup::ComponentInstance))

            # Check for entities that have been copied into a non-OpenStudio group and clean them.
            if (entity.parent.is_a? Sketchup::ComponentDefinition and not OpenStudio.get_drawing_interface(entity.parent.instances.first))
              OpenStudio.set_drawing_interface(entity, nil)
              OpenStudio.set_model_object_handle(entity, nil)
            end

            if drawing_interface.nil?
              drawing_interface = OpenStudio.get_drawing_interface(entity)

              Plugin.log(OpenStudio::Debug, "selected_drawing_interface = #{drawing_interface}")
            else
              drawing_interface = nil

              Plugin.log(OpenStudio::Debug, "reseting selected_drawing_interface")

              # try to revert back to group or building here
              parent = @model_interface.skp_model.active_entities.parent
              if (parent.is_a? Sketchup::ComponentDefinition)
                # Gets the SurfaceGroup interface that is currently open for editing
                drawing_interface = OpenStudio.get_drawing_interface(parent.instances.first)

                Plugin.log(OpenStudio::Debug, "selected_drawing_interface = #{drawing_interface}")
              else
                drawing_interface = @model_interface.building

                Plugin.log(OpenStudio::Debug, "selected_drawing_interface = #{drawing_interface}")
              end

              break
            end
          end
        end
      end

      return(drawing_interface)
    end

    def select_drawing_interfaces(handles)
      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")

      @selection.clear

      active_path = @model_interface.skp_model.active_path
      if active_path.nil?
        active_path = []
      end

      for child in @model_interface.recurse_children

        if child.is_a? DaylightingControl or
           child.is_a? IlluminanceMap or
           child.is_a? InteriorPartitionSurface or
           child.is_a? InteriorPartitionSurfaceGroup or
           child.is_a? Luminaire or
           child.is_a? ShadingSurface or
           child.is_a? ShadingSurfaceGroup or
           child.is_a? Space or
           child.is_a? SubSurface or
           child.is_a? Surface

          if child.model_object
            if handles.include?(child.model_object.handle)
              # do not select nil or deleted entities
              if child.valid_entity?

                #do not select object in active path
                if not active_path.include?(child.entity)
                  @selection.add(child.entity)
                end
              end
            end
          end
        end
      end

    end

  end

end
