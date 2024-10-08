########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class WriteSpaceTypeReport < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Space Type Report"
  end

  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    save_path = OpenStudio::Ruleset::OSArgument::makePathArgument("save_path", false, "csv",false)
    save_path.setDisplayName("Save Space Type Report As ")
    save_path.setDefaultValue("SpaceTypeReport.csv")
    result << save_path

    return result
  end

  def round(x, d)
    result = (x * 10**d).round.to_f / 10**d
    return result
  end

  def ft2_per_m2
    return (10.7639)
  end

  def m2_per_ft2
    return (1.0/ft2_per_m2)
  end

  def writeBuildingToFile(file, model)
    file.puts "Building, Space Type, Floor Area (ft^2), Lighting Power Density (W/ft^2), Electric Equipment Density (W/ft^2), People Density (people/1000*ft^2)"

    building = model.getBuilding

    building_name = building.name.to_s

    space_type = building.spaceType
    space_type_name = "<no space type>"
    if not space_type.empty?
      space_type_name = space_type.get.name.to_s
    end

    floor_area = round(ft2_per_m2*building.floorArea, 2)
    lpd = round(m2_per_ft2*building.lightingPowerPerFloorArea, 2)
    eed = round(m2_per_ft2*building.electricEquipmentPowerPerFloorArea, 2)
    pd = round(1000*m2_per_ft2*building.peoplePerFloorArea, 2)

    file.puts "#{building_name}, #{space_type_name}, #{floor_area}, #{lpd}, #{eed}, #{pd}"
    file.puts
  end


  def writeSpaceTypesToFile(file, model)
    file.puts "Space Type, Floor Area (ft^2), Number of Spaces"

    space_types = model.getSpaceTypes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    space_types.each do |space_type|
      spaces = space_type.spaces
      if not spaces.empty?
        writeSpaceTypeToFile(file, space_type.name.to_s, spaces)
      end
    end

    no_space_type_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each {|space| no_space_type_spaces << space if space.spaceType.empty?}

    if not no_space_type_spaces.empty?
      writeSpaceTypeToFile(file, "<no space type>", no_space_type_spaces)
    end

    file.puts
  end


  def writeSpaceTypeToFile(file, space_type_name, spaces)

    floor_area = 0
    spaces.each do |space|
      floor_area += space.floorArea
    end
    floor_area = round(ft2_per_m2*floor_area, 2)

    num_spaces = spaces.size

    file.puts "#{space_type_name}, #{floor_area}, #{num_spaces}"
  end


  def writeBuildingStoriesToFile(file, model)
    file.puts "Building Story, Floor Area (ft^2), Number of Spaces"

    stories = model.getBuildingStorys.sort {|x, y| x.name.to_s <=> y.name.to_s}
    stories.each do |story|
      spaces = story.spaces
      if not spaces.empty?
        writeBuildingStoryToFile(file, story.name.to_s, spaces)
      end
    end

    no_story_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each {|space| no_story_spaces << space if space.buildingStory.empty?}

    if not no_story_spaces.empty?
      writeBuildingStoryToFile(file, "<no building story>", no_story_spaces)
    end

    file.puts
  end


  def writeBuildingStoryToFile(file, story_name, spaces)

    floor_area = 0
    spaces.each do |space|
      floor_area += space.floorArea
    end
    floor_area = round(ft2_per_m2*floor_area, 2)

    num_spaces = spaces.size

    file.puts "#{story_name}, #{floor_area}, #{num_spaces}"
  end


  def writeSpacesToFile(file, model)

    file.puts "Space, Space Type, Thermal Zone, Building Story, Floor Area (ft^2), Lighting Power Density (W/ft^2), Electric Equipment Density (W/ft^2), People Density (people/1000*ft^2)"

    space_types = model.getSpaceTypes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    space_types.each do |space_type|
      spaces = space_type.spaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
      spaces.each do |space|
        writeSpaceToFile(file, space_type.name.to_s, space)
      end
    end

    no_space_type_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each do |space|
      if space.spaceType.empty?
        writeSpaceToFile(file, "<no space type>", space)
      end
    end

    file.puts
  end


  def writeSpaceToFile(file, space_type_name, space)

    space_name = space.name.to_s

    thermal_zone = space.thermalZone
    thermal_zone_name = "<no thermal zone>"
    if not thermal_zone.empty?
      thermal_zone_name = thermal_zone.get.name.to_s
    end

    building_story = space.buildingStory
    building_story_name = "<no building story>"
    if not building_story.empty?
      building_story_name = building_story.get.name.to_s
    end

    floor_area = round(ft2_per_m2*space.floorArea, 2)
    lpd = round(m2_per_ft2*space.lightingPowerPerFloorArea, 2)
    eed = round(m2_per_ft2*space.electricEquipmentPowerPerFloorArea, 2)
    pd = round(1000*m2_per_ft2*space.peoplePerFloorArea, 2)

    file.puts "#{space_name}, #{space_type_name}, #{thermal_zone_name}, #{building_story_name}, #{floor_area}, #{lpd}, #{eed}, #{pd}"
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    save_path = runner.getPathArgumentValue("save_path",user_arguments).to_s

    # create file
    File.open(save_path, 'w') do |file|
      writeBuildingToFile(file, model)
      writeBuildingStoriesToFile(file, model)
      writeSpaceTypesToFile(file, model)
      writeSpacesToFile(file, model)
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
WriteSpaceTypeReport.new.registerWithApplication

end