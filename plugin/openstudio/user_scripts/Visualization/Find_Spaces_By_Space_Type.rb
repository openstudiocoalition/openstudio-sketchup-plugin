########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class FindBySpaceType < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Find Spaces By Space Type"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    space_type_name = OpenStudio::Ruleset::makeChoiceArgumentOfWorkspaceObjects("space_type_name", "OS_SpaceType".to_IddObjectType, model, true)
    space_type_name.setDisplayName("Space Type")
    result << space_type_name

    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    space_type_handle = runner.getStringArgumentValue("space_type_name",user_arguments)
    # if the user doesn't pick a space type this part of script wont run. Model visibility is left in current state

    # get all spaces
    spaces = model.getSpaces

    runner.createProgressBar("Searching Spaces")
    num_total = spaces.size
    num_complete = 0

    # loop over each space
    spaces.each do |space|
      if drawing_interface = space.drawing_interface
        if entity = drawing_interface.entity

          space_type = space.spaceType

          if space_type_handle == space_type.get.handle.to_s
            entity.visible = true
          else
            entity.visible = false
          end

        end
      end
    end

    runner.destroyProgressBar

    # set hidden to visible so easier for users to select and unide
    Sketchup.active_model.rendering_options["DrawHidden"] = true

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
FindBySpaceType.new.registerWithApplication

end