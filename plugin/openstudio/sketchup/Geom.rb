########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2022, OpenStudio Coalition and other contributors. All rights reserved.
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

module OpenStudio

  # check if point is on a line segment
  def self.point_on_line_segment?(point, line)

    # In the SketchUp API:
    # A line can be represented as either an Array of a point and a vector, or as an Array of two points.
    # line = [Geom::Point3d.new(0,0,0), Geom::Vector3d.new(0,0,1)]
    # line = [Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,0,100)]

    # For the purposes of this method, the line MUST be defined as an array of two Point3d objects.
    # The Point3d/Vector3d version will not work.

    if (not point.on_line?(line))
      return(false)
    else
      start_point = line[0]
      end_point = line[1]

      # Check if the point is between the start point and the end point in each dimension
# NOTE: This is similar code to Geom::BoundingBox.intersects?--can it be reused?
      if ( (point.x >= start_point.x and point.x <= end_point.x) \
        or (point.x <= start_point.x and point.x >= end_point.x) )
        intersects_in_x = true
      else
        intersects_in_x = false
      end

      if ( (point.y >= start_point.y and point.y <= end_point.y) \
        or (point.y <= start_point.y and point.y >= end_point.y) )
        intersects_in_y = true
      else
        intersects_in_y = false
      end

      if ( (point.z >= start_point.z and point.z <= end_point.z) \
        or (point.z <= start_point.z and point.z >= end_point.z) )
        intersects_in_z = true
      else
        intersects_in_z = false
      end

      return(intersects_in_x and intersects_in_y and intersects_in_z)
    end

  end

  # return a Geom::Transformation from a OpenStudio::Transformation
  def self.transformation_from_openstudio(t)
    os_array = t.vector
    skp_array = []
    (0..11).each {|i| skp_array << os_array[i].to_f }
    (12..14).each {|i| skp_array << os_array[i].to_f.m }
    skp_array[15] = os_array[15].to_f
    return Geom::Transformation.new(skp_array)
  end

  # convert a Geom::Transformation to a OpenStudio::Transformation
  def self.transformation_to_openstudio(t)
    os_array = OpenStudio::Vector.new(16)
    skp_array = t.to_a
    (0..11).each {|i| os_array[i] = skp_array[i].to_f }
    (12..14).each {|i| os_array[i] = skp_array[i].to_f.to_m }
    os_array[15] = skp_array[15].to_f
    return OpenStudio::Transformation.new(os_array)
  end


  # This is a surrogate class for things I can't do directly with the regular Sketchup::Loop class.
  # The pure geometric analog of the Sketchup::Loop class.
  class PolygonLoop

    attr_writer :outer
    attr_reader :points

    # Should PolygonLoop always provide a reduced set of points, from the instant it is created?
    def initialize(arg1 = nil, arg2 = nil)
      if (arg1.is_a? Array)
        @points = arg1
      else
        @points = []
      end

      if (arg2 == true)
        @outer = true
      else
        @outer = false
      end
    end

    def inspect
      return(self)
    end

    # Vertices don't make sense for a polygon loop because it is not actually drawn by the API.
    #def vertices=(arg)
    #
    #end

    def points=(arg)
      # must be an array or a Sketchup::Loop
      if (arg.is_a? Array)
        @points = arg

        # check to make sure this is an array of Point3d objects?

        return(arg)
      else
        # Or better: raise an exception
        return(nil)
      end
    end

    def outer?
      return(@outer)
    end

    def clear
      @points = []
      @outer = false
    end

    def empty?
      return(@points.empty?)
    end

    def valid?
      reduced_points = self.reduce

      if (reduced_points.length < 3)
        raise ArgumentError, "polygon loop has less than 3 unique points"
      end

      # Verify that all of the points of the loop are in the plane
      plane = self.plane
      reduced_points.each { |point|
        if (not point.on_plane?(plane))
          raise ArgumentError, "not all points of the polygon loop are in the same plane"
        end
      }
      return(true)
    end

    def reduce
      # Returns a loop with all consecutive collinear and coincident points deleted

      if (@points.empty?)
        return(@points)
      end

      # Eliminate consecutive coincident points
      non_coinc_points = []
      for i in 0...@points.length
        this_point = @points[i]

        if (i == @points.length - 1)
          next_point = @points.first
        else
          next_point = @points[i + 1]
        end

        # Check to make sure this point is not coincident with the next point
        if (next_point != this_point)
          non_coinc_points << this_point
        else
          puts "coincident point skipped"
        end
      end
      if (non_coinc_points.empty?)  # All points are coincident
        non_coinc_points = [ @points[0] ]
      end

  # another way
      # Delete any consecutive duplicate points (duplicates that are not consecutive are okay)
      #prev_point = points[0]
      #for i in 1...points.length
      #  if (points[i] == prev_point)
      #    points[i] = nil
      #    puts "deleting a duplicate point"
      #  else
      #    prev_point = points[i]
      #  end
      #end
      #points = points.compact


      # Eliminate consecutive collinear points
      reduced_points = []
      if (non_coinc_points.length < 3)
        reduced_points = non_coinc_points
      else
        prev_vector = non_coinc_points.first - non_coinc_points.last
        for i in 0...non_coinc_points.length
          this_point = non_coinc_points[i]

          if (i == non_coinc_points.length - 1)
            next_point = non_coinc_points.first
          else
            next_point = non_coinc_points[i + 1]
          end

          this_vector = next_point - this_point

          # Check to make sure this point is not collinear with the next point
          if (not this_vector.samedirection?(prev_vector))
            reduced_points << this_point
          else
            #puts "collinear point skipped"
          end
          prev_vector = this_vector
        end
      end

      return(reduced_points)
    end

    def reduce!
      return(@points = self.reduce)
    end

    def normal
      # Assume the loop is valid
      reduced_points = self.reduce
      if (not reduced_points.empty?)

        # The algorithm below fails for concave polygons!
        #normal_vector = reduced_points[0].vector_to(reduced_points[1]) * reduced_points[1].vector_to(reduced_points[2])
        #return(normal_vector.normalize)

        coefficients = self.plane  # self method already corrects for strange API precision error
        return(Geom::Vector3d.new(coefficients[0..2]))
      else
        puts "PolygonLoop.normal: loop has no points"
        return(nil)
      end
    end

    def reverse
      return(PolygonLoop.new(@points.reverse, @outer))
    end

    def reverse!
      @points.reverse!
      return(self)
    end

    def plane
      # Assume the loop is valid

      # Something strange can happen here where the z component of the vector comes out as 1, not 1.0
      # And this 1 is not equal to 1.0, yet both claim to be of class Float.
      # That's why I'm using fit_plane_to_points instead.

      #normal_vector = self.normal
      #a = normal_vector.x.to_f
      #b = normal_vector.y.to_f
      #c = normal_vector.z.to_f
      #d = - (a * @points[0].x.to_f) - (b * @points[0].y.to_f) - (c * @points[0].z.to_f)
      #coefficients = [ a, b, c, d ]  # Equation of the plane

      coefficients = Geom.fit_plane_to_points(@points)

      # Check for values close to zero, like e-16...seems like API bug
      for i in 0..3
        if (coefficients[i].abs < 1e-8)
          coefficients[i] = 0.0
        end
      end
      return(coefficients)
    end

    def transform(transformation)
      new_points = []
      @points.each { |point| new_points << point.transform(transformation) }
      return(PolygonLoop.new(new_points, @outer))
    end

    def transform!(transformation)
      @points.each { |point| point.transform!(transformation) }
      return(self)
    end

  end # PolygonLoop


  # Not strictly a native class, but this gets used like a native class and helps extend the functionality
  # of some of the native geometry API classes.
  # Polygon is the purely geometric analog of the Face class, kind of like the way Point3d is to Vertex.
  class Polygon

    attr_reader :loops, :outer_loop

    def initialize(arg = nil)
      clear
      if (arg.is_a? PolygonLoop or arg.is_a? Array)
        add_loop(arg)
      end
    end

    def inspect
      return(self)
    end

    def points
      points_array = []
      for polygon_loop in @loops
        polygon_loop.points.each { |point| points_array << point }
      end
      return(points_array)
    end

    def add_loop(arg)
      if (arg.is_a? PolygonLoop)
        new_loop = arg
      elsif (arg.is_a? Array)
        new_loop = PolygonLoop.new(arg)
      else
        raise ArgumentError
      end

      # Check to make sure this loop is not already present?

      if (@loops.empty?)
        new_loop.outer = true
        @outer_loop = new_loop
      end

      @loops << new_loop

      return(new_loop)
    end

    def clear
      @outer_loop = nil
      @loops = []
    end

    def reduce
      new_polygon = Polygon.new
      @loops.each { |polygon_loop| new_polygon.add_loop(polygon_loop.reduce) }
      return(new_polygon)
    end

    def reduce!
      @loops.each { |polygon_loop| polygon_loop.reduce! }
      return(self)
    end

    def empty?
      return(@loops.empty?)
    end

    def valid?
      # check each loop, but then also check that inner loops are correct
      @loops.each { |polygon_loop| polygon_loop.valid? }  # Raises an ArgumentError if not valid
      return(true)
    end

    def normal
      # Assume the polygon is valid
      if (@outer_loop.nil?)
        return(nil)
      else
        return(@outer_loop.normal)
      end
    end

    def reverse
      new_polygon = Polygon.new
      @loops.each { |polygon_loop| new_polygon.add_loop(polygon_loop.reverse) }
      return(new_polygon)
    end

    def reverse!
      @loops.each { |polygon_loop| polygon_loop.reverse! }
      return(self)
    end

    def plane
      # Assume the polygon is valid
      if (@outer_loop.nil?)
        return(nil)
      else
        return(@outer_loop.plane)
      end
    end

    def transform(transformation)
      new_polygon = Polygon.new
      @loops.each { |polygon_loop| new_polygon.add_loop(polygon_loop.transform(transformation)) }
      return(new_polygon)
    end

    def transform!(transformation)
      @loops.each { |polygon_loop| polygon_loop.transform!(transformation) }
      return(self)
    end

    def eql?(other)

      result = false

      points1 = points
      points2 = other.points

      if (points1.length == points2.length)
        result = true
        points1.each_index do |i|
          if points1[i] != points2[i]
            result = false
            break
          end
        end
      end

      return result
    end

    def ==(other)
      return self.eql?(other)
    end

    def circular_eql?(other)
      result = false

      points1 = self.reduce.points
      points2 = other.reduce.points

      if (points1.length == points2.length)
        for i in 0..points1.length-1
          if i > 0
            temp = points2[i..-1].concat(points2[0..i-1])
          else
            temp = points2
          end
          if temp[0] == points1[0]
            result = true
            points1.each_index do |j|
              if points1[j] != temp[j]
                result = false
                break
              end
            end
          end
        end
      end

      return result
    end

    def get_area(points)
      newell = newell_vector(points)
      return newell.length / 2.0;
    end

    def newell_vector(points)
      result = Geom::Vector3d.new
      for i in 1...points.length-1
        v1 = points[i] - points[0]
        v2 = points[i + 1] - points[0]
        result = result + v1.cross(v2)
      end
      return result
    end

    def get_centroid(pts) #calculates the centroid of the polygon
      total_area = 0
      total_centroids = Geom::Vector3d.new(0,0,0)
      third = Geom::Transformation.scaling(1.0 / 3.0)
      npts = pts.length
      vec1 = Geom::Vector3d.new(pts[1].x - pts[0].x, pts[1].y - pts[0].y, pts[1].z - pts[0].z)
      vec2 = Geom::Vector3d.new(pts[2].x - pts[0].x, pts[2].y - pts[0].y, pts[2].z - pts[0].z)
      ref_sense = vec1.cross vec2
      for i in 0...(npts-2)
        vec1 = Geom::Vector3d.new(pts[i+1].x - pts[0].x, pts[i+1].y - pts[0].y, pts[i+1].z - pts[0].z)
        vec2 = Geom::Vector3d.new(pts[i+2].x - pts[0].x, pts[i+2].y - pts[0].y, pts[i+2].z - pts[0].z)
        vec = vec1.cross vec2
        area = vec.length / 2.0
        if(ref_sense.dot(vec) < 0)
           area *= -1.0
        end
        total_area += area
        centroid = (vec1 + vec2).transform(third)
        t = Geom::Transformation.scaling(area)
        total_centroids += centroid.transform(t)
      end
      c = Geom::Transformation.scaling(1.0 / total_area)
      vec = total_centroids.transform!(c) + Geom::Vector3d.new(pts[0].x,pts[0].y,pts[0].z)
      return Geom::Point3d.new(vec.x, vec.y, vec.z)
    end

    def loose_match?(other, debug = false)
      points1 = self.reduce.points
      points2 = other.reduce.points

      centroid1 = get_centroid(points1)
      centroid2 = get_centroid(points2)

      if centroid1.distance(centroid2) > 1*Length::Centimeter
        puts "centroids differ too much #{centroid1.distance(centroid2)}" if debug
        return false
      end

      area1 = get_area(points1)
      area2 = get_area(points2)

      tol = 0.005
      if (area1-area2).abs/area1 > tol or (area1-area2).abs/area2 > tol
        puts "areas differ too much #{area1}, #{area2}, #{(area1-area2).abs/area1}, #{(area1-area2).abs/area2}" if debug
        return false
      end

      # search for one point in common
      i = 0
      j = 0
      found = false
      for i in 0..points1.length-1
        for j in 0..points2.length-1
          if points1[i] == points2[j]
            done = true
            break
          end
        end
        break if done
      end

      if not done
        puts "no points in common" if debug
        return false
      end

      # shift points, after this points1[0] == points2[0]
      points1 = points1[i..-1].concat(points1[0..i-1]) if i > 0
      points2 = points2[j..-1].concat(points2[0..j-1]) if j > 0

      puts "points1 = #{points1}" if debug
      puts "points2 = #{points2}" if debug

      # matches1 is the index in points2 (j) which matches the point1 at i
      j = 0
      last_match = 0
      matches1 = [0]
      for i in 1..points1.length-1
        matches1[i] = nil
        for j in last_match..points2.length-1
          if points1[i] == points2[j]
            last_match = j
            matches1[i] = j
            break
          end
        end
      end

      # matches2 is the index in points1 (i) which matches the point2 at j
      i = 0
      last_match = 0
      matches2 = [0]
      for j in 1..points2.length-1
        matches2[j] = nil
        for i in last_match..points1.length-1
          if points1[i] == points2[j]
            last_match = i
            matches2[j] = i
            break
          end
        end
      end

      puts "matches1 = #{matches1}" if debug
      puts "matches2 = #{matches2}" if debug

      # create polygons that go from last match to next match and then back to first match
      polygons = []
      polygon = [points1[0]]
      puts "start first polygon 0" if debug
      puts "add point1 0" if debug
      for i in 1..points1.length-1
        puts "add point1 #{i}" if debug
        polygon << points1[i]
        if matches1[i]
          # just added points1[i] which is the same as points2[matches1[i]]
          # now go backward until the previous match
          j = matches1[i] - 1
          while matches2[j].nil?
            puts "add point2 #{j}" if debug
            polygon << points2[j]
            j -= 1
            break if j < 0
          end
          if polygon.length > 2
            puts "close #{polygon}" if debug
            polygons << polygon
          end
          puts "start new polygon #{i}" if debug
          puts "add point1 #{i}" if debug
          polygon = [points1[i]]
        elsif i == points1.length-1
          # polygon was not closed, start at end of points2
          # now go backward until the previous match
          j = matches2.length - 1
          while matches2[j].nil?
            puts "add point2 #{j}" if debug
            polygon << points2[j]
            j -= 1
            break if j < 0
          end
          if polygon.length > 2
            puts "close #{polygon}" if debug
            polygons << polygon
          end
        end
      end

      puts "polygons = #{polygons}" if debug

      deconstructed_polygons = []
      polygons.each do |polygon|
        for i in 1..polygon.length-2
          # the area of these deconstructed_polygons blows up for non-simple polygons but that is what we want
          deconstructed_polygons << [polygon[0], polygon[i], polygon[i+1]]
        end
      end

      areas = []
      deconstructed_polygons.each {|p| areas << get_area(p).abs}

      puts "areas = #{areas}" if debug

      area = 0
      areas.each {|a| area+= a}

      puts "area = #{area}" if debug

      tol = 0.005
      if area/area1 > tol || area/area2 > tol
        puts "relative area too large #{area/area1} #{area/area2}" if debug
        return false
      end

      return true
    end

    def intersect(other_polygon)
      return(Geom.intersect_polygon_polygon(self, other_polygon))  # array of polygons
    end

  end # Polygon


  def self.point_in_polygon_loop(point, polygon_loop, include_border = false)

    # tests that everything is in the plane, and has >3 vertices
    if (not polygon_loop.valid?)
      return(false)
    end

    # Other argument testing?  make sure point is a Point3d?  make sure points is an array?

    # Check if the point is on the same plane as the polygon
    if (not point.on_plane?(polygon_loop.plane))
      return(false)
    end

    # DLM: wondering if point_in_polygon_2D is sufficiently solid to use now?
    return Geom.point_in_polygon_2D(point, polygon_loop.points, include_border)

    # DLM: this is legacy code that was written when point_in_polygon_2D was not working right

    # This is a substitute for point_in_polygon_2D, which does not seem to be functional.

    # TO DO:  The looping-over-points can probably be condensed into a fewer number of loops

    # Check if the point is on a vertex, i.e., on the border
    polygon_loop.points.each { |p|
      if (p == point)  # Automatically uses the standard SketchUp tolerance to compare

        #puts "point found on a vertex"

        # The point is on the border--the test can conclude one way or the other
        if (include_border)
          return(true)
        else
          return(false)
        end
      end
    }

    # Check if the point is on an edge, i.e., on the border
    for i in 0...polygon_loop.points.length  # Check each loop separately
      start_point = polygon_loop.points[i]

      if (i < polygon_loop.points.length - 1)
        end_point = polygon_loop.points[i + 1]
      else
        end_point = polygon_loop.points[0]
      end

      if (point_on_line_segment?(point, [ start_point, end_point ] ))
        #puts "point found on an edge"

        # The point is on the border--the test can conclude one way or the other
        if (include_border)
          return(true)
        else
          return(false)
        end
      end
    end

    # Use the Crossing Number Algorithm to test the interior area of the polygon

    # Identifying all crossing points where a ray drawn from the test point intersects the polygon edges.
    ray_vector = polygon_loop.points[0].vector_to(polygon_loop.points[1])  # Just need any vector in the plane of the polygon
    ray_line = [ point, ray_vector ]
    crossing_points = []

    for i in 0...polygon_loop.points.length
      start_point = polygon_loop.points[i]

      if (i < polygon_loop.points.length - 1)
        end_point = polygon_loop.points[i + 1]
      else
        end_point = polygon_loop.points[0]
      end

      line = [ start_point, end_point ]

      intersection_point = intersect_line_line(ray_line, line)

      if (not intersection_point.nil?)  # nil means the lines are parallel

        if (point_on_line_segment?(intersection_point, line))
          #puts "crossing point found"

          crossing_vector = point.vector_to(intersection_point)

          # Check to make sure the crossing point is in the direction of the ray
          if (crossing_vector.samedirection?(ray_vector))

            # Check to make sure the intersection point is not a duplicate (usually generated by crossing a vertex)
            duplicate = false
            crossing_points.each { |p|
              if (intersection_point == p)
                duplicate = true
                break
              end
            }
            if (not duplicate)
              crossing_points << intersection_point
            end
          end

        end
      end
    end

    #puts "unique crossing points in ray direction=" + crossing_points.length.to_s

    #puts crossing_points

    # Check if number of crossing points is even or odd
    if (crossing_points.length.modulo(2) == 0)
      return(false)  # Even:  According to Crossing Number Algorithm => outside of polygon
    else
      return(true)  # Odd:  According to Crossing Number Algorithm => inside of polygon
    end

  end


  # check if a point is inside a polygon
  def self.point_in_polygon(point, polygon, include_border = false)

    # Check if point is contained by the outer loop
    if (point_in_polygon_loop(point, polygon.outer_loop, include_border))

      # Check if point is contained by an inner loop, a.k.a., a "hole" (and therefore not on the polygon)
      for this_loop in polygon.loops
        if (not this_loop.outer?)  # There is always only one outer loop
          if (point_in_polygon_loop(point, this_loop, !include_border))  # NOTE: The border condition is inverted here
            return(false)
          end
        end
      end
      return(true)
    else
      return(false)
    end

  end


  # Crossing Number version
  # This version is computationally faster, but has problems with multiple vertices on a shared edge.
  # That's why I'm trying the Midpoint Test version
  def self.find_shared_line_segments_old(points1, points2)
    # If necessary, performance can be improved by doing only 2 point_in_polygon checks for the whole method,
    # one per polygon.  Right now, doing one per vertex of each polygon.

    line_segments = []

    # Circulate around polygon 1
    for i in 0...points1.length
      start_point = points1[i]

      if (i < points1.length - 1)
        end_point = points1[i + 1]
      else
        end_point = points1[0]  # Close the loop
      end

      # Check if the edge crosses any edges from polygon 2
      intersections = []
      line1 = [ start_point, end_point ]
      for j in 0...points2.length
        start_point2 = points2[j]

        if (j < points2.length - 1)
          end_point2 = points2[j + 1]
        else
          end_point2 = points2[0]  # Close the loop
        end

        line2 = [ start_point2, end_point2 ]
        intersection_point = intersect_line_line(line1, line2)

        if (not intersection_point.nil?)  # nil means the lines are parallel
          if (point_on_line_segment?(intersection_point, line1) and point_on_line_segment?(intersection_point, line2))
            puts "intersection found"
            intersections << [start_point.distance(intersection_point), intersection_point]
          end
        end
      end

      # Check if the start point is inside of polygon 2
      if (point_in_polygon(start_point, points2, false))  # don't include border...I guess
        inside_polygon = true
      else
        inside_polygon = false
      end

      prev_vertex = start_point

      # Sort and add the new intersections based on proximity to the start point
      intersections.sort!  # Sorts the array by distance

      # Use the Crossing Number Principle to keep track of when inside and outside of the polygon
      for intersection in intersections
        this_vertex = intersection[1]
        if (inside_polygon)
          line_segments << [prev_vertex, this_vertex]
          inside_polygon = false
        else
          inside_polygon = true
        end
        prev_vertex = this_vertex
      end

      if (inside_polygon)
        line_segments << [prev_vertex, end_point]
      end
    end

    return(line_segments)

  end


  # Midpoint Test version
  #
  def self.find_shared_line_segments(polygon1, polygon2)
    # Find all the line segments from polygon 1 that are inside of polygon 2, works with holes

    line_segments = []

    # Circulate around polygon 1
    for i_loop in polygon1.loops
      for i in 0...i_loop.points.length
        start_point = i_loop.points[i]

        if (i < i_loop.points.length - 1)
          end_point = i_loop.points[i + 1]
        else
          end_point = i_loop.points[0]  # Close the loop
        end

        # Check if the edge crosses any edges from any loops of polygon 2
        intersections = []
        line1 = [ start_point, end_point ]

        for j_loop in polygon2.loops
          for j in 0...j_loop.points.length
            start_point2 = j_loop.points[j]

            if (j < j_loop.points.length - 1)
              end_point2 = j_loop.points[j + 1]
            else
              end_point2 = j_loop.points[0]  # Close the loop
            end

            line2 = [ start_point2, end_point2 ]
            intersection_point = intersect_line_line(line1, line2)

            if (not intersection_point.nil?)  # nil means the lines are parallel
              if (point_on_line_segment?(intersection_point, line1) and point_on_line_segment?(intersection_point, line2))
                distance = start_point.distance(intersection_point)
                if (distance > 0.0)
                  intersections << [distance, intersection_point]
                end
              end
            end
          end
        end

        # Sort and add the new intersections based on proximity to the start point
        intersections.sort!  # Sorts the array by distance

        prev_point = start_point
        for intersection in intersections
          this_point = intersection[1]
          if (this_point != start_point and this_point != end_point)
            line_segments << [prev_point, this_point]
            prev_point = this_point
          end
        end
        line_segments << [prev_point, end_point]
      end
    end

    # Test each line segment to see if it is inside or outside of the polygon; borders points are included
    for i in 0...line_segments.length
      mid_point = Geom.linear_combination(0.5, line_segments[i][0], 0.5, line_segments[i][1])
      if (not point_in_polygon(mid_point, polygon2, true))
        line_segments[i] = nil
      end
    end
    line_segments = line_segments.compact

    return(line_segments)

  end


  def self.intersect_polygon_polygon(polygon1, polygon2)
    # Should be able to handle convex and concave polygons.
    # Partially handles holes in polygons, adds the "hole" polygons to the list, but they
    # should be added as inner loops to the returned polygons.

    polygon1.valid?
    polygon2.valid?

    # Check to make sure the polygons have the same vertex order, i.e., outward normal vector
    if (not polygon1.normal.samedirection?(polygon2.normal))
      polygon2 = polygon2.reverse
    end

    if (polygon1.plane != polygon2.plane)
      puts "polygons are on different planes!"
      return([])
    end

    line_segments = []
    line_segments1 = find_shared_line_segments(polygon1, polygon2)
    line_segments2 = find_shared_line_segments(polygon2, polygon1)

    line_segments += line_segments1
    line_segments += line_segments2

    puts "segments 1-2:"
    line_segments1.each { |s| puts s[0].to_s + "  " + s[1].to_s }
    puts "end"

    puts "segments 2-1:"
    line_segments2.each { |s| puts s[0].to_s + "  " + s[1].to_s }
    puts "end"


    # Remove duplicates (possible if there are any shared edges)
    for i in 0...line_segments.length
      for j in 0...line_segments.length
        if (i != j and line_segments[i] == line_segments[j])
          #puts "deleting duplicate"
          line_segments[j] = nil
        end
      end
    end
    line_segments = line_segments.compact

    #puts "reduced line segs"
    #line_segments.each { |s| puts s[0].to_s + "  " + s[1].to_s }

    loops = []
    #return

    # Process the line segments into an array of loops by connecting start points to end points
    this_loop = []
    while (line_segments.length > 0)

      if (this_loop.length == 0)
        # Start a new loop with the first remaining element in the array
        line_segment = line_segments.shift
        start_point = line_segment[0]
        prev_end_point = line_segment[1]
        this_loop << start_point
      end

      # Search the remaining line segments for a start point that matches the previous segment's end point
      found = false
      for i in 0...line_segments.length
        line_segment = line_segments[i]
        start_point = line_segment[0]
        end_point = line_segment[1]

        if (start_point == prev_end_point)
          # Found the next line segment
          this_loop << start_point
          prev_end_point = end_point
          line_segments.slice!(i)  # Remove the element from the array

          # Check to see if the loop has closed--the end point of the segment must match the start of the loop
          if (end_point == this_loop.first)
            loops << this_loop
            this_loop = []
          end

          found = true
          break
        end
      end

      if (not found)
        # Could not find another segment with a matching start point--must be some kind of orphan
        # Start a new loop
        loops << this_loop
        this_loop = []
      end
    end

    # Delete any degenerate loops
    for i in 0...loops.length
      if (loops[i].length < 3)
        puts "********degenerate found"
        loops[i] = nil
      end
    end
    loops = loops.compact

    loops.each { |lp| puts "loop:"; puts lp }

    polygons = []
    loops.each { |this_loop| polygons << Polygon.new(this_loop) }

    return(polygons)  # an array of polygons
  end



  # the following are test methods which rely on the SketchUp API, they can be called manually

  def self.test_point_in_polygon(x, y, z, include_border)
    p = Point3d.new(x, y, z)

    concave = [ Point3d.new(0,0,0), Point3d.new(5,0,0), Point3d.new(5,5,0), Point3d.new(1,5,0), Point3d.new(1,10,0), Point3d.new(5,10,0), Point3d.new(5,15,0), Point3d.new(0,15,0) ]

    square = [ Point3d.new(0,0,0), Point3d.new(5,0,0), Point3d.new(5,1,0), Point3d.new(5,5,0), Point3d.new(0,5,0) ]

    degen = [ Point3d.new(0,0,0), Point3d.new(5,0,0), Point3d.new(5,0,0), Point3d.new(5,2,0), Point3d.new(5,2,1) ]

    if (point_in_polygon(p, square, include_border))
      puts "point is inside the polygon"
    else
      puts "point is outside the polygon"
    end
  end


  def self.test_intersect

    faces = []
    Sketchup.active_model.selection.each { |element|
      if (element.is_a? Sketchup::Face)
        faces << element
      end
    }

    if (faces.length == 2)
      f1 = faces[1]
      f2 = faces[0]

      puts "face1.area=" + f1.area.to_s
      puts "face2.area=" + f2.area.to_s

      polygons = OpenStudio.intersect_faces(f1, f2)

      if (polygons.length > 0)
        puts "intersection"

        Sketchup.active_model.selection.clear

        for this_polygon in polygons

          new_polygon = this_polygon.transform(Geom::Transformation.translation(Geom::Vector3d.new(0,0,1.0)))
          # floats the intersection like 1" above...

          new_face = Sketchup.active_model.entities.add_face(new_polygon.points)
          Sketchup.active_model.selection.add(new_face.all_connected)
        end
      else
        puts "NO intersection"
      end

    end

  end


  def self.test_intersect_polygon_polygon

    polygon1 = Polygon.new( [ Point3d.new(0,0,0), Point3d.new(0,5,0), Point3d.new(5,5,0), Point3d.new(5,0,0) ] )
    #points2 = [ Point3d.new(5,0,0), Point3d.new(5,5,0), Point3d.new(10,5,0), Point3d.new(10,0,0) ]

    return(Geom.intersect_polygon_polygon(polygon1, polygon1).points)

  end


  def self.test_loose_match

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    puts "1 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5.01,2,0), Geom::Point3d.new(5,0,0) ] )
    puts "2 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5.01,2,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    puts "3 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(6,5,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(6,0,0), Geom::Point3d.new(5,0,0) ] )
    puts "4 #{polygon1.loose_match?(polygon2)} should be false"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5.01,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    puts "5 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5.01,0,0) ] )
    puts "6 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(5.01,2,0), Geom::Point3d.new(5,0,0), Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(5,0,0), Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0) ] )
    puts "7 #{polygon1.loose_match?(polygon2)} should be true"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,5,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(5,0,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(5,0,0), Geom::Point3d.new(5,5,0), Geom::Point3d.new(10,5,0), Geom::Point3d.new(10,0,0) ] )
    puts "8 #{polygon1.loose_match?(polygon2)} should be false"

    polygon1 = Polygon.new( [ Geom::Point3d.new(0,2,0), Geom::Point3d.new(0,3,0), Geom::Point3d.new(5,3,0), Geom::Point3d.new(5,2,0) ] )
    polygon2 = Polygon.new( [ Geom::Point3d.new(2,0,0), Geom::Point3d.new(2,5,0), Geom::Point3d.new(3,5,0), Geom::Point3d.new(3,0,0) ] )
    puts "9 #{polygon1.loose_match?(polygon2)} should be false"

  end

end
