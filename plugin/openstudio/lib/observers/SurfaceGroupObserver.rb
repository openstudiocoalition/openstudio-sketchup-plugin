########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  # This class is used for both Space Groups and Detached Shading Groups.
  class SurfaceGroupObserver < Sketchup::EntityObserver

    def initialize(drawing_interface)
      @drawing_interface = drawing_interface
      @enabled = false
    end

    def disable
      was_enabled = @enabled
      @enabled = false
      return was_enabled
    end

    def enable
      @enabled = true
    end

    def destroy
      @drawing_interface = nil
      @enabled = false
    end

    # Group was moved, scaled, or rotated.
    # Note that onChangeEntity is NOT triggered for the enclosed entities!
    # Vertices of the enclosed entities DO NOT change...instead a transformation is applied to the Group.
    def onChangeEntity(entity)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      # http://www.thomthom.net/software/sketchup/observers/#note_EntityObserver
      # EntityObserver.onChangeEntity mistriggers right before EntityObserver.onEraseEntity, referencing a non-existant entity.
      # EntityObserver.onEraseEntity reference a non-existant entity.

      proc = Proc.new {

        # When a group is erased, one last call to 'onChangeEntity' is still issued.
        if (@drawing_interface.valid_entity?)
          @drawing_interface.on_change_entity
        end
      }

      Plugin.add_event( proc )

    end


    # Group was erased or otherwise deleted.
    # onEraseEntity IS subsequently triggered for the enclosed entities.
    def onEraseEntity(entity)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      # http://www.thomthom.net/software/sketchup/observers/#note_EntityObserver
      # EntityObserver.onChangeEntity mistriggers right before EntityObserver.onEraseEntity, referencing a non-existant entity.
      # EntityObserver.onEraseEntity reference a non-existant entity.

      proc = Proc.new {
        @drawing_interface.on_erase_entity
      }

      Plugin.add_event( proc )

    end

  end


end
