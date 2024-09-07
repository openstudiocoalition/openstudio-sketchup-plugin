########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  # Add drawing_interface to WorkspaceObject
  class WorkspaceObject

    @@drawing_interface_hash = Hash.new

    # returns the OpenStudio::DrawingInterface associated with this ModelObject
    def drawing_interface
      object = nil
      if (drawing_interface_id = @@drawing_interface_hash[self.handle.to_s])
        begin
          object = ObjectSpace._id2ref(drawing_interface_id)
        rescue
          # The id_string does not reference an existing object!  Ignore the exception.
        ensure
          # Sometimes a bad reference can turn into a real object...but a random one, not the one we want.
          if (object and not object.is_a?(OpenStudio::DrawingInterface))
            puts "ModelObject.drawing_interface:  bad object reference"
            object = nil
            # To detect copy-paste between SketchUp sessions, could set 'object' to a value that can be detected on the
            # receiving end by whichever Observer the entity is pasted into.
          end
        end
      end
      return(object)
    end

    def drawing_interface=(object)
      @@drawing_interface_hash[self.handle.to_s] = object.object_id
    end

  end

end
