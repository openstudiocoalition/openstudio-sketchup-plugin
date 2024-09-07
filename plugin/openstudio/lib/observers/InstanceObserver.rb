########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  # This is a kludge to get a selection update when a Group is closed after being edited.
  # SelectionObserver does not provide any event.  Fortunately, InstanceObserver, which
  # also happens to work for Groups, DOES give an event that can be used.
  class InstanceObserver < Sketchup::InstanceObserver

    def initialize(drawing_interface)
      # for drawing interfaces that want update_entity on close
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

    #def onOpen(group)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #  http://www.thomthom.net/software/sketchup/observers/#note_InstanceObserver
    #  Under OSX, when using this observer SketchUp will crash when the user quits SketchUp without saving the model first. Quiting and then choosing to save will also cause crash.
    #  SketchUp under Windows does not suffer from this.
    #
    #end

    #def onClose(group)
    #
    #  Plugin.log(OpenStudio::Trace, "#{OpenStudio.current_method_name}, @enabled = #{@enabled}")
    #
    #  return if not @enabled
    #
    #  http://www.thomthom.net/software/sketchup/observers/#note_InstanceObserver
    #  Under OSX, when using this observer SketchUp will crash when the user quits SketchUp without saving the model first. Quiting and then choosing to save will also cause crash.
    #  SketchUp under Windows does not suffer from this.
    #
    #end

  end


end
