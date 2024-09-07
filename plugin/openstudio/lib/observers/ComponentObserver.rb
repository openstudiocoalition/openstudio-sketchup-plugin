########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/DrawingUtils")

module OpenStudio

  class ComponentObserver < Sketchup::EntityObserver

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

    def onChangeEntity(entity)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      # http://www.thomthom.net/software/sketchup/observers/#note_EntityObserver
      # EntityObserver.onChangeEntity mistriggers right before EntityObserver.onEraseEntity, referencing a non-existant entity.
      # EntityObserver.onEraseEntity reference a non-existant entity.

      proc = Proc.new {
        @drawing_interface.on_change_entity
      }
      Plugin.add_event( proc )
    end

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
