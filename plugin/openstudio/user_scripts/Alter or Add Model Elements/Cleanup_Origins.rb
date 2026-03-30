########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class CleanupOrigins < OpenStudio::Measure::ModelMeasure

  # override name to return the name of your script
  def name
    return "Cleanup Origins"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    return result
  end

  def cleanup_group(group)
      boundingBox = group.transformation*group.boundingBox

      if boundingBox.isEmpty
        return
      end

      matrix = OpenStudio::Matrix.new(4,4,0)
      matrix[0,0] = 1
      matrix[1,1] = 1
      matrix[2,2] = 1
      matrix[3,3] = 1
      matrix[0,3] = boundingBox.minX.get
      matrix[1,3] = boundingBox.minY.get
      matrix[2,3] = boundingBox.minZ.get
      translation = OpenStudio::Transformation.new(matrix)
      group.changeTransformation(translation)
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)


    # get all spaces
    spaces = model.getSpaces
    shading_groups = model.getShadingSurfaceGroups
    interior_partition_groups = model.getInteriorPartitionSurfaceGroups

    runner.createProgressBar("Cleaning Up Origins")
    num_total = spaces.size + shading_groups.size + interior_partition_groups.size
    num_complete = 0

    runner.updateProgressTitle("Cleaning Up Origins - Spaces")
    # do spaces first as these may contain other groups
    spaces.each do |space|
      num_complete += 1
      next if not runner.inSelection(space)
      cleanup_group(space)

      space.shadingSurfaceGroups.each do |group|
        cleanup_group(group)
      end

      space.interiorPartitionSurfaceGroups.each do |group|
        cleanup_group(group)
      end

      runner.updateProgress((100*num_complete)/num_total)
    end

    # now do shading surfaces
    runner.updateProgressTitle("Cleaning Up Origins - Shading Surface Groups")
    shading_groups.each do |group|
      num_complete += 1
      next if not runner.inSelection(group)
      cleanup_group(group)

      runner.updateProgress((100*num_complete)/num_total)
    end

    # now do interior partition surface groups
    runner.updateProgressTitle("Cleaning Up Origins - Interior Partition Surface Groups")
    interior_partition_groups.each do |group|
      num_complete += 1
      next if not runner.inSelection(group)
      cleanup_group(group)

      runner.updateProgress((100*num_complete)/num_total)
    end

    runner.updateProgress(100)

    runner.destroyProgressBar

    true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
CleanupOrigins.new.registerWithApplication

end
