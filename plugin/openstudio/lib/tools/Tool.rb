########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  class Tool

    def initialize
      #@cursor = UI.create_cursor(Plugin.dir + "/lib/resources/icons/Cursor.tiff", 1, 1)
    end


    def onSetCursor
      UI.set_cursor(@cursor)
    end


    # The activate method is called by SketchUp when the tool is first selected.
    # It is a good place to put most of your initialization.
    def activate
      # The Sketchup::InputPoint class is used to get 3D points from screen
      # positions.  It uses the SketchUp inferencing code.
      @ip = Sketchup::InputPoint.new
      Sketchup.active_model.selection.clear
    end


    # The draw method is called whenever the view is refreshed.  It lets the
    # tool draw any temporary geometry that it needs to.
    def draw(view)
      @ip.draw(view)
    end


    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate #if (@ip.display?)
    end


    def onLButtonUp(flags, x, y, view)
      @ip.pick(view, x, y)
    end


    def onLButtonDoubleClick(flags, x, y, view)
      @ip.pick(view, x, y)
    end


    # onCancel is called when the user hits the escape key.
    def onCancel(flag, view)
      Sketchup.active_model.tools.pop_tool
    end


    # See Tool documentation...can override context menu completely
    #def getMenu
    #end

    # onUserText is called when the user enters something into the VCB
    # In this implementation, we create a line of the entered length if
    # the user types a length while selecting the second point
    #def onUserText(text, view)
    #end

  end


end
