########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class AssignBuildingStories < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Assign Building Stories"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    return result
  end

  # find the first story with z coordinate, create one if needed
  def getStoryForNominalZCoordinate(model, minz)

    model.getBuildingStorys.each do |story|
      z = story.nominalZCoordinate
      if not z.empty?
        if minz == z.get
          return story
        end
      end
    end

    story = OpenStudio::Model::BuildingStory.new(model)
    story.setNominalZCoordinate(minz)
    return story
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # get all spaces
    spaces = model.getSpaces

    runner.createProgressBar("Assigning Stories to Spaces")

    # make has of spaces and minz values
    sorted_spaces = Hash.new
    spaces.each do |space|
      # loop through space surfaces to find min z value
      z_points = []
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          z_points << vertex.z
        end
      end
      minz = z_points.min + space.zOrigin
      sorted_spaces[space] = minz
    end

    # pre-sort spaces
    sorted_spaces = sorted_spaces.sort{|a,b| a[1]<=>b[1]}

    num_total = spaces.size
    num_complete = 0

    # this should take the sorted list and make and assign stories
    sorted_spaces.each do |space|
      space_obj = space[0]
      space_minz = space[1]
      if space_obj.buildingStory.empty?

        story = getStoryForNominalZCoordinate(model, space_minz)
        runner.registerInfo("Setting story of Space " + space_obj.name.get + " to " + story.to_s + ".")
        space_obj.setBuildingStory(story)

        num_complete += 1
        runner.updateProgress((100*num_complete)/num_total)
      end
    end

    runner.destroyProgressBar

  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
AssignBuildingStories.new.registerWithApplication

end