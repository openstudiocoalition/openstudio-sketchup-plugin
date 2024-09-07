########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/DrawingUtils")

module OpenStudio

  class EntitiesObserver < Sketchup::EntityObserver

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

    #def onElementAdded(entities, entity)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #end

    def onElementModified(entities, entity)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      proc = Proc.new {
        @drawing_interface.on_change_entity
      }
      Plugin.add_event( proc )
    end

    #def onElementRemoved(entities, entity_id)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #end

    #def onEraseEntities(entities)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #end

  end

end
