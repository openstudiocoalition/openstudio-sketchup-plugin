########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/interfaces/ModelInterface")

module OpenStudio

  class MaterialsObserver < Sketchup::MaterialsObserver

    def initialize(materials_interface)
      @materials_interface = materials_interface
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
      @materials_interface = nil
      @enabled = false
    end

    #def onMaterialAdd(materials, material)
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #end

    def onMaterialChange(materials, material)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      proc = Proc.new {
        if !material.deleted? and OpenStudio.get_drawing_interface(material)
          OpenStudio.get_drawing_interface(material).update_model_object
        end
      }
      Plugin.add_event( proc )
    end

    #def onMaterialRefChange(materials, material)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #  http://www.thomthom.net/software/sketchup/observers/#note_onMaterialRefChange
    #  When purging materials, or right-clicking a material in the Material Browser, this event triggers one time for every entity with a material. This causes a long series of events to trigger unnecessarily.
    #
    #end

    #def onMaterialRemove(materials, material)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #  # this event will be handled by the material's EntityObserver
    #end

    #def onMaterialSetCurrent(materials, material)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #end

    #def onMaterialUndoRedo(materials, material)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #end

  end

end
