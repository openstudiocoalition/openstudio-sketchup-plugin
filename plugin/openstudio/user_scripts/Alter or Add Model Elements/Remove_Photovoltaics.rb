########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class RemovePhotovoltaics < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Remove Photovoltaics"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    choices = OpenStudio::StringVector.new
    choices << "Yes"
    choices << "No"

    remove_elcd = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("remove_elcd", choices, choices, true)
    remove_elcd.setDisplayName("Remove Empty Electric Load Center Distribution And Orphaned Inverters?")
    remove_elcd.setDefaultValue("Yes")
    result << remove_elcd

    return result
  end


  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model,runner,user_arguments) # initializes runner for new script

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    remove_elcd = runner.getStringArgumentValue("remove_elcd",user_arguments)

    num_pv_removed = 0
    num_elcd_removed = 0
    num_inverter_removed = 0

    model.getPlanarSurfaces.each do |s|

      # Only remove for selected surfaces
      next if not runner.inSelection(s)

      s.generatorPhotovoltaics.each do |pv|
        pv.remove
        num_pv_removed += 1
      end

    end

    if remove_elcd == "Yes"
      # remove ElectricLoadCenterDistributions without any generators
      model.getElectricLoadCenterDistributions.each do |elcd|
        if elcd.generators.empty?
          inverter = elcd.inverter
          if !inverter.empty?
            inverter.get.remove
            num_inverter_removed += 1
          end
          elcd.remove
          num_elcd_removed += 1
        end
      end

      # remove inverters that are not connected to an ElectricLoadCenterDistribution
      model.getInverters.each do |inverter|
        if inverter.electricLoadCenterDistribution.empty?
          inverter.remove
          num_inverter_removed += 1
        end
      end
    end

    if (num_pv_removed + num_elcd_removed + num_inverter_removed) == 0
      runner.registerAsNotApplicable("No objects removed.")
    else
      runner.registerInfo("#{num_pv_removed} GeneratorPhotovoltaic, #{num_elcd_removed} ElectricLoadCenterDistribution, #{num_inverter_removed} Inverter objects removed.")
    end

    return(true)
  end
end

# this call registers your script with the OpenStudio SketchUp plug-in
RemovePhotovoltaics.new.registerWithApplication

end