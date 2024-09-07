########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/ShadingSurfaceGroup")
require("openstudio/lib/tools/NewGroupTool")


module OpenStudio

  class NewShadingSurfaceGroupTool < NewGroupTool

    def onMouseMove(flags, x, y, view)
      super
      Sketchup.set_status_text("Select a point to become the New Shading Group")
      view.tooltip = "New Shading Group"
    end


    def onLButtonUp(flags, x, y, view)
      super

      model_interface = Plugin.model_manager.model_interface

      this_space = nil
      if model_interface.skp_model.active_path
        model_interface.spaces.each do |space|
          if space.entity == model_interface.skp_model.active_path[-1]
            # good
            this_space = space
            break
          end
        end
      end

      if not model_interface.skp_model.active_path.nil? and not this_space
        UI.messagebox("Shading Surface Group should be added at the top level of a SketchUp model or directly under a Space")
        Sketchup.send_action("selectSelectionTool:")
        return false
      end

      begin

        model_interface.start_operation("New Shading Surface Group", true)

        # input point is in absolute coordinates
        initial_position = nil

        had_observers = nil

        shading_group = ShadingSurfaceGroup.new
        shading_group.create_model_object
        if this_space
          had_observers = this_space.remove_observers

          shading_group.model_object.setSpace(this_space.model_object)
          initial_position = this_space.coordinate_transformation.inverse * @ip.position
          #initial_position = @ip.position
        else
          had_observers = model_interface.building.remove_observers

          initial_position = @ip.position
        end

        shading_group.model_object.setXOrigin(initial_position.x.to_m)
        shading_group.model_object.setYOrigin(initial_position.y.to_m)
        shading_group.model_object.setZOrigin(initial_position.z.to_m)
        shading_group.draw_entity
        shading_group.create_initial_box("#{OpenStudio::SKETCHUPPLUGIN_DIR}/resources/components/OpenStudio_NewShadingSurfaceGroup.skp")
        shading_group.add_observers
        shading_group.add_watcher

      ensure

        model_interface.commit_operation

      end

      if had_observers
        if this_space
          this_space.add_observers
        else
          model_interface.building.add_observers
        end
      end

      # selection observers will ignore signals because selection tool is not yet active
      model_interface.skp_model.selection.clear
      model_interface.skp_model.selection.add(shading_group.entity)
      Plugin.dialog_manager.selection_changed

      # pick selection tool after changing selection
      Sketchup.send_action("selectSelectionTool:")

    end

  end

end
