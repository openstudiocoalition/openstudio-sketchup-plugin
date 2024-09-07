########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class MoveSelectedSurfacesToNewSpace < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Move Selected Surfaces to New Space"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # make new space
    newSpace = OpenStudio::Model::Space.new(model)

    # we will set the new space origin at the first space's origin
    haveSetOrigin = false

    # this doesn't show correctly until you reload model, also needs to be transformed.
    # change parent space
    model.getSurfaces.each do |surface|

      # is this surface in the selection
      next if not runner.inSelection(surface)

      # surface must belong to a space
      oldSpace = surface.space
      next if oldSpace.empty?
      oldSpace = oldSpace.get

      # is this space in the selection
      # might not want to allow space level selections
      #next if runner.inSelection(oldSpace)

      if not haveSetOrigin
        newSpace.setTransformation(oldSpace.transformation)
        haveSetOrigin = true
      end

      # transformation from old space coordinates to new space coordinates
      transformation = newSpace.transformation.inverse * oldSpace.transformation

      # re-assign surface to new space
      surface.setSpace(newSpace)

      # transform surface vertices
      newVertices = transformation * surface.vertices
      surface.setVertices(newVertices)

      # transform any sub surfaces too
      surface.subSurfaces.each do |subSurface|
        newVertices = transformation * subSurface.vertices
        subSurface.setVertices(newVertices)
      end

      # might want to remove the oldSpace if it is now empty
      #oldSpace.remove if oldSpace.surfaces.empty?
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
MoveSelectedSurfacesToNewSpace.new.registerWithApplication

end