########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class HideSpacesInBuildingArea < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Hide Spaces Included In Building Area"
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

    #this script is not portable, uses SketchUp specific methods

    # get all spaces
    spaces = model.getSpaces

    runner.createProgressBar("Hiding Spaces Included in Building Area")
    num_total = spaces.size
    num_complete = 0

    # loop over each space
    spaces.each do |space|
      if drawing_interface = space.drawing_interface
        if entity = drawing_interface.entity

          if space.partofTotalFloorArea
            # hide space if part of floor area
            entity.visible = false
          else
            # unide space if it is hidden
            entity.visible = true
          end
        end
      end

      num_complete += 1
      runner.updateProgress((100*num_complete)/num_total)
    end

    runner.destroyProgressBar

    # set hidden to visible so easier for users to select and unide
    Sketchup.active_model.rendering_options["DrawHidden"] = true

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
HideSpacesInBuildingArea.new.registerWithApplication

end