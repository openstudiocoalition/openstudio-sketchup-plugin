########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class SelectionObserver < Sketchup::SelectionObserver

    def initialize(selection_interface)
      @selection_interface = selection_interface
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
      @selection_interface = nil
      @enabled = false
    end

    # docs say this is not implemented correctly
    #def onSelectionAdded(*args)
    #
    #  return if not @enabled
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #
    #  http://www.thomthom.net/software/sketchup/observers/#note_SelectionObserver
    #  onSelectionBulkChange triggers instead of onSelectionAdded and onSelectionRemoved.
    #  Release notes of SketchUp 8.0 claims the events where fixed, but this appear to not be the case.
    #
    #  # Called when a new entity is added to the selection.
    #  if (Sketchup.active_model.tools.active_tool_id == 21022) # selection tool
    #    Plugin.dialog_manager.selection_changed
    #  end
    #end


    def onSelectionBulkChange(selection)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      #  http://www.thomthom.net/software/sketchup/observers/#note_SelectionObserver
      #  onSelectionBulkChange triggers instead of onSelectionAdded and onSelectionRemoved.
      #  Release notes of SketchUp 8.0 claims the events where fixed, but this appear to not be the case.

      # Called for almost every change in selection, except when going to no selection (onSelectionCleared gets called instead).
      if (Sketchup.active_model.tools.active_tool_id == 21022) # selection tool
        Plugin.dialog_manager.selection_changed
      end
    end


    def onSelectionCleared(selection)

      Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")

      return if not @enabled

      #  http://www.thomthom.net/software/sketchup/observers/#note_SelectionObserver
      #  onSelectionBulkChange triggers instead of onSelectionAdded and onSelectionRemoved.
      #  Release notes of SketchUp 8.0 claims the events where fixed, but this appear to not be the case.

      # Called when going from a selection to an empty selection.
      if (Sketchup.active_model.tools.active_tool_id == 21022) # selection tool
        Plugin.dialog_manager.selection_changed
      end
    end


    # docs say this is not implemented correctly
    #def onSelectionRemoved(selection)
    #
    #  return if not @enabled
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}")
    #
    #  # Not sure when this is called.
    #end

  end

end
