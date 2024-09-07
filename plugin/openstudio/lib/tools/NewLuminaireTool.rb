########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/tools/Tool")
require("openstudio/lib/interfaces/Luminaire")

module OpenStudio

  class NewLuminaireTool < Tool

    def initialize
      @cursor = UI.create_cursor(Plugin.dir + "/lib/resources/icons/OriginToolCursor-14x20.tiff", 3, 3)
    end

    def onMouseMove(flags, x, y, view)
      super
      # Should apply user's precision setting here   --automatically done, I think
      # Also:  show relative coordinates?
      Sketchup.set_status_text("Select a point to insert the Luminaire = " + @ip.position.to_s)
      view.tooltip = "New Luminaire"
    end


    def onLButtonUp(flags, x, y, view)
      super

      model_interface = Plugin.model_manager.model_interface

      # look for this group in the spaces
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

      if not this_space
        UI.messagebox "You need to be in a Space to add a Luminaire"
        Sketchup.send_action("selectSelectionTool:")
        return false
      end

      had_observers = this_space.remove_observers

      begin

        model_interface.start_operation("New Luminaire", true)

        initial_position = @ip.position
        if @ip.face
          # bump up or in by 30" if placed on a face
          distance = @ip.face.normal
          distance.length = 30.0
          initial_position = initial_position - distance
        end

        rotation = Geom::Transformation.rotation(Geom::Point3d.new(0,0,0), Geom::Vector3d.new(0,1,0), 180.degrees)
        translation = Geom::Transformation::translation(initial_position)

        luminaire = Luminaire.new
        luminaire.create_model_object
        luminaire.model_object.setSpace(this_space.model_object)
        luminaire.model_object_transformation = this_space.coordinate_transformation.inverse * translation * rotation
        luminaire.draw_entity
        luminaire.add_observers
        luminaire.add_watcher

      ensure

        model_interface.commit_operation

      end

      this_space.add_observers if had_observers

      # selection observers will ignore signals because selection tool is not yet active
      model_interface.skp_model.selection.clear
      model_interface.skp_model.selection.add(luminaire.entity)
      Plugin.dialog_manager.selection_changed

      # pick selection tool after changing selection
      Sketchup.send_action("selectSelectionTool:")

    end

  end

end
