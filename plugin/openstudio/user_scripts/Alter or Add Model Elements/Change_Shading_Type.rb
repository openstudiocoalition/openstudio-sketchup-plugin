########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class ChangeShadingType < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Change Shading Type"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    choices = OpenStudio::StringVector.new
    choices << "Site"
    choices << "Building"
    shading_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("shading_type", choices, false)
    shading_type.setDisplayName("Shading Type")
    shading_type.setDefaultValue("Site")
    result << shading_type

    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model,runner,user_arguments) # initializes runner for new script

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    shading_type = runner.getStringArgumentValue("shading_type",user_arguments)

    if shading_type == "Site"
      # need to ensure that site exists
      site = model.getSite
    end

    any_in_selection = false
    model.getShadingSurfaceGroups.each do |s|

      next if not runner.inSelection(s)

      next if s.shadingSurfaceType == "Space"

      any_in_selection = true

      test = s.setShadingSurfaceType(shading_type)

      if !test
        runner.registerWarning("Unable to set shading type of " + s.name.get + " to " + shading_type.to_s + ".")
      end
    end

    if not any_in_selection
      runner.registerAsNotApplicable("No shading surface groups in the current selection.  Please select shading surface groups at top level to change shading type.")
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
ChangeShadingType.new.registerWithApplication

end