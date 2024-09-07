########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class RemoveUnusedThermalZones < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Remove Unused ThermalZones"
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
    continue_operation = runner.yesNoPrompt("This will remove thermal zones without spaces or equipment. Click Yes to proceed, click No to cancel.")
    if not continue_operation
      puts "Operation canceled, your model was not altered."
      runner.registerAsNotApplicable("Operation canceled, your model was not altered.")
      return true
    end

    thermal_zones = model.getThermalZones

    thermal_zone_handles_to_remove = OpenStudio::UUIDVector.new
    thermal_zones.each do |thermal_zone|
      if thermal_zone.spaces.empty? && thermal_zone.equipment.empty? && thermal_zone.isRemovable
        thermal_zone_handles_to_remove << thermal_zone.handle
      end
    end

    if not thermal_zone_handles_to_remove.empty?
      model.removeObjects(thermal_zone_handles_to_remove)
      runner.registerFinalCondition("Removing #{thermal_zone_handles_to_remove.size} thermal zones.")
    else
      runner.registerFinalCondition("No unused thermal zones to remove.")
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
RemoveUnusedThermalZones.new.registerWithApplication

end