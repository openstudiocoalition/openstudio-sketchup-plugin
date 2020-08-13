########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC, and other contributors. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
#  disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative works
#  may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without specific prior
#  written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED
#  STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################################################

require("openstudio/sketchup/Geom")


module OpenStudio

  def self.is_subset_of?(array, other)

    for element in array

      element_matched = false

      for other_element in other
        if (other_element == element)
          element_matched = true
          break
        end
      end

      if (not element_matched)
        # no match
        return(false)
      end
    end

    return(true)
  end


  def self.is_same_set?(array, other)
    if (array.length == other.length and self.is_subset_of?(array, other))
      return(true)
    else
      return(false)
    end
  end


  def self.set_hsba(color, color_array)
    h = color_array[0] / 360.to_f  # HSV values = 0 � 1
    s = color_array[1] / 100.to_f
    v = color_array[2] / 100.to_f
    a = color_array[3]

    if (s == 0)
      color.red = v * 255
      color.green = v * 255
      color.blue = v * 255
      color.alpha = a
    else
      var_h = h * 6
      var_h = 0 if (var_h == 6)  # H must be < 1
      var_i = var_h.floor
      var_1 = v * (1 - s)
      var_2 = v * (1 - s * (var_h - var_i))
      var_3 = v * (1 - s * (1 - (var_h - var_i)))

      if (var_i == 0)
       var_r = v
       var_g = var_3
       var_b = var_1
      elsif (var_i == 1)
       var_r = var_2
       var_g = v
       var_b = var_1
      elsif (var_i == 2)
        var_r = var_1
        var_g = v
        var_b = var_3
      elsif (var_i == 3)
        var_r = var_1
        var_g = var_2
        var_b = v
      elsif (var_i == 4)
        var_r = var_3
        var_g = var_1
        var_b = v
      else
        var_r = v
        var_g = var_1
        var_b = var_2
      end

      color.red = (var_r * 255).to_i  # RGB results = 0 � 255
      color.green = (var_g * 255).to_i
      color.blue = (var_b * 255).to_i
      color.alpha = a
    end
    return(color)
  end
  
  def self.get_openstudio_path(skp_model)
    return(skp_model.get_attribute('OpenStudio', 'OpenStudioPath'))
  end

  def self.set_openstudio_path(skp_model, path)
    OpenStudio::Plugin.log(OpenStudio::Trace, "#{current_method_name}")

    skp_model.set_attribute('OpenStudio', 'OpenStudioPath', path)
  end
  
  def self.get_model_interface(skp_model)
    object = nil
    if (id_string = skp_model.get_attribute('OpenStudio', 'ModelInterface'))
      begin
        object = ObjectSpace._id2ref(id_string.to_i)
      rescue
        # The id_string does not reference an existing object!  Ignore the exception.
      ensure
        # Sometimes a bad reference can turn into a real object...but a random one, not the one we want.
        if (object and not object.is_a?(OpenStudio::ModelInterface))
          puts "OpenStudio.get_model_interface:  bad object reference"
          object = nil
        end
      end
    end
    return(object)
  end

  def self.set_model_interface(skp_model, object)
    OpenStudio::Plugin.log(OpenStudio::Trace, "#{current_method_name}")

    skp_model.set_attribute('OpenStudio', 'ModelInterface', object.object_id.to_s)
  end
  
  def self.get_openstudio_entities(skp_model)
    result = []
    skp_model.entities.each {|e| result << e if e.model_object_handle }
    return result
  end
  
  def self.get_openstudio_materials(skp_model)
    result = []
    skp_model.materials.each {|m| result << m if m.model_object_handle }
    return result
  end
  
  def self.delete_openstudio_entities(skp_model)
    # DLM: for some reason there is no delete_attribute for SketchUp::Model
    # delete_attribute('OpenStudio') # deletes entire attribute dictionary
    skp_model.set_attribute('OpenStudio', 'OpenStudioPath', nil)
    skp_model.set_attribute('OpenStudio', 'ModelInterface', nil)
    skp_model.entities.erase_entities(skp_model.openstudio_entities)
  end
end


class Sketchup::Entity

  # returns a string
  def model_object_handle
    return(get_attribute('OpenStudio', 'Handle'))
  end

  # takes a OpenStudio::Handle or a string
  def model_object_handle=(handle)
    OpenStudio::Plugin.log(OpenStudio::Trace, "#{current_method_name}")

    set_attribute('OpenStudio', 'Handle', handle.to_s)
  end

  # returns the OpenStudio::DrawingInterface associated with this Entity
  def drawing_interface
    object = nil
    if (id_string = get_attribute('OpenStudio', 'DrawingInterface'))
      begin
        object = ObjectSpace._id2ref(id_string.to_i)
      rescue
        # The id_string does not reference an existing object!  Ignore the exception.
      ensure
        # Sometimes a bad reference can turn into a real object...but a random one, not the one we want.
        if (object and not object.is_a?(OpenStudio::DrawingInterface))
          puts "Entity.drawing_interface:  bad object reference"
          object = nil
          # To detect copy-paste between SketchUp sessions, could set 'object' to a value that can be detected on the
          # receiving end by whichever Observer the entity is pasted into.
        end
      end
    end
    return(object)
  end

  def drawing_interface=(object)
    OpenStudio::Plugin.log(OpenStudio::Trace, "#{current_method_name}")

    set_attribute('OpenStudio', 'DrawingInterface', object.object_id.to_s)
  end

end

class Sketchup::Loop

# should this return a polygon or a polygon loop?

  def polygon_loop
    points = []
    self.vertices.each do |vertex|
      # DLM@20100920: weird bug in SU 8 that vertices can also return attribute dictionary for a loop's vertices
      if vertex.class == Sketchup::Vertex
        points << vertex.position
      end
    end
    return(OpenStudio::PolygonLoop.new(points))
  end

end




class Sketchup::Face

  def outer_polygon
    return(OpenStudio::Polygon.new(self.outer_loop.polygon_loop))
  end


  def full_polygon
    this_polygon = self.outer_polygon
    for this_loop in self.loops
      if (not this_loop.outer?)
        this_polygon.add_loop(this_loop.polygon_loop.points)
      end
    end
    return(this_polygon)
  end


  def contains_point?(point, include_border = false)
    return(OpenStudio.point_in_polygon(point, self.full_polygon, include_border))
  end


  def intersect(other_face)
    return(OpenStudio.intersect_polygon_polygon(self.full_polygon, other_face.full_polygon))  # array of polygons
  end

end



class Sketchup::ShadowInfo

  # Still need to reconcile daylight saving time between EnergyPlus and SketchUp


  def time
    # API bug:  ShadowTime is returning the hour incorrectly in UTC/GMT time, but the time zone is (correctly) the local one.
    #           Also year is ALWAYS 2002.
    # Example:  Noon on Nov 8 returns Fri Nov 08 04:50:11 Mountain Standard Time 2002
    # SUBTRACT the utc offset to get the correct local time.
    return(convert_to_utc(self['ShadowTime']))
  end


  def time=(new_time)
    # API bug:  ShadowTime is returning the hour incorrectly in UTC/GMT time, but the time zone is (correctly) the local one.
    #           Also year is ALWAYS 2002.
    # Example:  Noon on Nov 8 returns Fri Nov 08 04:50:11 Mountain Standard Time 2002
    # ADD the utc offset to set the correct local time.
    self['ShadowTime'] = new_time + new_time.utc_offset
    # if ShadowTime is already in UTC, this won't do anything...offset = 0
    return(time)
  end


  def dst?
    return(time.dst?)
  end


  def sunrise
    return(convert_to_utc(self['SunRise']))
  end


  def sunset
    return(convert_to_utc(self['SunSet']))
  end


  def zone_offset=(new_zone_offset)
    # Sets the time zone in hours offset from UTC/GMT.  NOTE:  Negative numbers indicate Western hemisphere.
    # API bug:  Setting ShadowTime['TZOffset'] alone does not set this.
    self['TZOffset'] = new_zone_offset
    # No way to change the time zone for the Time object in Ruby...?
    # Might consider putting all time as UTC, handle daylight savings myself.
    return(nil)
  end

  def north_angle
    return(self['NorthAngle'])
  end

private
  def convert_to_utc(time)
    # API bug:  ShadowTime is returning the hour incorrectly in UTC/GMT time, but the time zone is (correctly) the local one.
    #           Also year is ALWAYS 2002.
    # Example:  Noon on Nov 8 returns Fri Nov 08 04:50:11 Mountain Standard Time 2002
    # SUBTRACT the utc offset to get the correct local time.
    a = (time - time.utc_offset).to_a
    return( Time.utc(a[0], a[1], a[2], a[3], a[4], Time.now.year, a[6], a[7], a[8], a[9]) )
  end

end
