########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

require("openstudio/lib/tools/Tool")


module OpenStudio

  class InfoTool < Tool
    # Features To Add:
    #   identify groups as spaces (use pickhelper) -- difficult
    #   doubleclick to open a group -- not possible in the API
    #   possible allow changing of selection
    #   with Ctrl key down, it displays construction objects!  --- used to work

    def initialize
      @cursor = UI.create_cursor(Plugin.dir + "/lib/resources/icons/InfoToolCursor-16x17.tiff", 1, 1)
      @flags = 0
    end


    def onMouseMove(flags, x, y, view)
      super

      # Should apply user's precision setting here
      # Also:  show relative coordinates?
      Sketchup.set_status_text("World Coordinates:  " + @ip.position.to_s)

      # flags are good here, reset them
      @flags = flags

      view.tooltip = get_tooltip(@ip.face, flags, view)
    end


    def onKeyDown(key, repeat, flags, view)

      # seem to get bad value for flags here
      if key == CONSTRAIN_MODIFIER_KEY # Shift Key
        if not ((@flags & CONSTRAIN_MODIFIER_MASK) > 0)
          @flags += CONSTRAIN_MODIFIER_MASK
        end
      elsif key == COPY_MODIFIER_KEY # Menu on Mac, Ctrl on PC
        if not ((@flags & COPY_MODIFIER_MASK) > 0)
          @flags += COPY_MODIFIER_MASK
        end
      elsif key == ALT_MODIFIER_KEY # Command on Mac, Alt on PC
        if not ((@flags & ALT_MODIFIER_MASK) > 0)
          @flags += ALT_MODIFIER_MASK
        end
      end

      view.tooltip = get_tooltip(@ip.face, @flags, view)
    end


    def onKeyUp(key, repeat, flags, view)

      # seem to get bad value for flags here
      if key == CONSTRAIN_MODIFIER_KEY # Shift Key
        if ((@flags & CONSTRAIN_MODIFIER_MASK) > 0)
          @flags -= CONSTRAIN_MODIFIER_MASK
        end
      elsif key == COPY_MODIFIER_KEY # Menu on Mac, Ctrl on PC
        if ((@flags & COPY_MODIFIER_MASK) > 0)
          @flags -= COPY_MODIFIER_MASK
        end
      elsif key == ALT_MODIFIER_KEY # Command on Mac, Alt on PC
        if ((@flags & ALT_MODIFIER_MASK) > 0)
          @flags -= ALT_MODIFIER_MASK
        end
      end

      view.tooltip = get_tooltip(@ip.face, @flags, view)
    end


    def get_tooltip(face, flags, view)

      tooltip = ""

      if (face)

        drawing_interface = OpenStudio.get_drawing_interface(face)

        if not drawing_interface
          parent = face.parent
          while parent and parent.is_a?(Sketchup::ComponentDefinition) or parent.is_a?(Sketchup::ComponentInstance) or parent.is_a?(Sketchup::Group)
            if drawing_interface = OpenStudio.get_drawing_interface(parent)
              break
            else
              if parent.is_a?(Sketchup::ComponentDefinition)
                if parent.instances.empty?
                  parent = nil
                else
                  parent = parent.instances[0]
                end
              else
                parent = parent.parent
              end
            end
          end

        end

        if (drawing_interface)

          # Determine if the camera is looking at the inside or outside of the face
          vector = @ip.position - view.camera.eye
          inside_info = false
          if (vector % face.normal < 0.0)  # Outside
            inside_info = false
          else
            inside_info = true
          end

          tooltip = drawing_interface.tooltip(flags, inside_info)

        end
      end

      return(tooltip)
    end


    def onLButtonDoubleClick(flags, x, y, view)
      super

      if (@ip.face)
        #$f = @ip.face
        #puts $f
        #puts $f.model_object_key

        #puts "relative coordinates"
        #$f.vertices.each { |v| puts v.position }
        #puts

        #puts "insertion point"
        #puts $f.parent.insertion_point

        #t = $f.parent.instances.first.transformation
        #puts "world coordinates"
        #$f.vertices.each { |v| puts (v.position).transform(t) }
        #puts

        #puts "DrawingInterface="
        #puts OpenStudio.get_drawing_interface($f)
      end

      if (@ip.edge)
        #$e = @ip.edge
      end

      #$ip = @ip.position

      #puts
      #puts "Face=>       " + $f.to_s
      #puts "Interface=>  " + OpenStudio.get_drawing_interface($f).to_s
      #puts "EntityID=>   " + $f.entityID.to_s   # useless...always matched to the same Face
      #puts "Key=>        " + OpenStudio.get_model_object_handle($f).to_s
      #puts "Base Face=>  " + DrawingUtils.find_base_face($f).to_s   # this is not working right
      #puts

      #$g = $f.parent.instances.first

      #puts "Group=>      " + $g.to_s
      #puts "Grp Intrfc=> " + OpenStudio.get_drawing_interface($g).to_s
      #puts "Entities=>   " + $g.entities.to_s
      #puts "Entities[]=> " + $g.entities.to_a.to_s


      #puts $f.entityID

      #$f.drawing_interface.surface_polygon.points.each { |v| puts v.display }

      #puts $f
      #puts OpenStudio.get_drawing_interface($f)
      #$f.vertices.each { |v| puts v.position.display }
      #puts

      #if (OpenStudio.face_contains_point?($f, @ip.position, include_border = true))
      #  puts "face contains point"
      #else
      #  puts "face DOES NOT contain point"
      #end

      #puts $f.classify_point($ip)
      # 1 = inside of all edges
      # 2 = on an edge
      # 4 = on a vertex
      # 8 = off the face completely, but still in the same plane
      # 16 = off the face completely, and not even on the same plane

      #PointUnknown = 0;
      #PointInside = 1;
      #PointOnEdge = 2;
      #PointOnVertex = 4
      #PointOutside = 8;
      #PointNotOnPlane = 16;

    end

  end

end
