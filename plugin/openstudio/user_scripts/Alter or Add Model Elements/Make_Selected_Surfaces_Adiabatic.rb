########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class MakeSelectedSurfacesAdiabatic < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Make Selected Surfaces Adiabatic and Assign a Construction"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    construction_name = OpenStudio::Ruleset::makeChoiceArgumentOfWorkspaceObjects("construction_name", "OS_Construction".to_IddObjectType, model, false)
    construction_name.setDisplayName("Pick a Construction For Selected Surfaces (Optional)")
    result << construction_name

    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    # change boundary condition
    model.getSurfaces.each do |surface|
      if runner.inSelection(surface)
        surface.setOutsideBoundaryCondition("Adiabatic")
      end
    end

    construction_name = runner.getStringArgumentValue("construction_name",user_arguments)
    return true if construction_name.empty?

    construction_uuid = OpenStudio::toUUID(construction_name)

    construction = nil
    c = model.getConstructionBase(construction_uuid)
    if c.empty?
      runner.registerError("Unable to locate construction " + construction_name + " in model.")
      return false
    end
    construction = c.get

    runner.registerInfo("Setting selected surfaces' construction to " + construction.briefDescription + ".")

    # if construction was picked, apply to surfaces
    model.getSurfaces.each do |surface|
      if runner.inSelection(surface)
        surface.setConstruction(construction)
      end
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
MakeSelectedSurfacesAdiabatic.new.registerWithApplication

end