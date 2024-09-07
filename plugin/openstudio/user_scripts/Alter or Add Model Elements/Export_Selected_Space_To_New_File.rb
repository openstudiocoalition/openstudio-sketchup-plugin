########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class ExportSpaces < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Export Selected Spaces to a new External Model"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    save_path = OpenStudio::Ruleset::OSArgument::makePathArgument("save_path", false, "osm", false)
    save_path.setDisplayName("Save Export Spaces As ")
    save_path.setDefaultValue("ExportedSpaces.osm")
    result << save_path

    begin
      SKETCHUP_CONSOLE.show
    rescue => e
    end

    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    osmPath_2 = runner.getPathArgumentValue("save_path",user_arguments).to_s

    # stop script if no spaces are selected.
    anyInSelection = false
    model.getSpaces.each do |space|
      if runner.inSelection(space)
        anyInSelection = true
        break
      end
    end

    if not anyInSelection
      runner.registerAsNotApplicable("No spaces selected.")
      return true
    end

    # create a new empty model
    model_2 = OpenStudio::Model::Model.new

    # loop through and clone spaces
    count = 0
    model.getSpaces.each do |space|
      if runner.inSelection(space)
        runner.registerInfo("Adding " + space.briefDescription + " to " + osmPath_2.to_s + ".")
        space.clone(model_2)
        count += 1
      end
    end

    # save as osm
    model_2.save(OpenStudio::Path.new(osmPath_2),true)
    runner.registerFinalCondition("File named '"+ osmPath_2 + "' created with " + count.to_s + " spaces.")
    puts 'File named "'+ osmPath_2 + '" has been generated'

  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
ExportSpaces.new.registerWithApplication

end