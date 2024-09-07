########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class RemoveLoadsDirectlyAssignedToSpaces < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Remove Loads Directly Assigned to Spaces"
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

    # this was added to give the user a chance to cancel the operation if they inadvertently hit it
    continue_operation = runner.yesNoPrompt("This will remove all loads directly assigned to a space, click No to cancel.")
    if not continue_operation
      puts "Operation canceled, your model was not altered."
      runner.registerAsNotApplicable("Operation canceled, your model was not altered.")
      return true
    end

    spaces = model.getSpaces

    spaces.each do |space|

      # removing or detaching loads directly assigned to space objects.
      space.internalMass.each {|instance| instance.remove }
      space.people.each {|instance| instance.remove }
      space.lights.each {|instance| instance.remove }
      space.luminaires.each {|instance| instance.remove }
      space.electricEquipment.each {|instance| instance.remove }
      space.gasEquipment.each {|instance| instance.remove }
      space.hotWaterEquipment.each {|instance| instance.remove }
      space.steamEquipment.each {|instance| instance.remove }
      space.otherEquipment.each {|instance| instance.remove }
      space.spaceInfiltrationDesignFlowRates.each {|object| object.remove }
      space.spaceInfiltrationEffectiveLeakageAreas.each {|object| object.remove }

      space.resetDesignSpecificationOutdoorAir

    end

  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
RemoveLoadsDirectlyAssignedToSpaces.new.registerWithApplication

end