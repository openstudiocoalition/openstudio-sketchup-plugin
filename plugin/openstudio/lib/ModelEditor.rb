########################################################################################################################
#  OpenStudio(R), Copyright (c) OpenStudio Coalition and other contributors.
#  See also https://openstudiocoalition.org/about/software_license/
########################################################################################################################

module OpenStudio

  # Maps each SpaceLoadInstance IDD type name (upper-case, colon-style) to:
  #   :definition_type  – IDD type name of the matching Definition object
  #   :field_index      – index of the "Definition Name" field in the instance object
  SPACE_LOAD_DEFINITION_MAP = {
    'OS:ELECTRICEQUIPMENT' => { definition_type: 'OS_ElectricEquipment_Definition',  field_index: 2 },
    'OS:GASEQUIPMENT'      => { definition_type: 'OS_GasEquipment_Definition',        field_index: 2 },
    'OS:HOTWATEREQUIPMENT' => { definition_type: 'OS_HotWaterEquipment_Definition',   field_index: 2 },
    'OS:INTERNALMASS'      => { definition_type: 'OS_InternalMass_Definition',        field_index: 2 },
    'OS:LIGHTS'            => { definition_type: 'OS_Lights_Definition',              field_index: 2 },
    'OS:LUMINAIRE'         => { definition_type: 'OS_Luminaire_Definition',           field_index: 2 },
    'OS:PEOPLE'            => { definition_type: 'OS_People_Definition',              field_index: 2 },
  }.freeze

  # Pure-Ruby replacement for OpenStudio::Modeleditor::ensureSpaceLoadDefinition.
  #
  # Ensures that the given SpaceLoadInstance workspace object has a linked
  # Definition object.  If the instance already points to a definition, returns
  # immediately.  Otherwise:
  #   1. If the model contains existing definitions of the matching type, asks
  #      the user whether to reuse one (picks the first) or create a new one.
  #   2. Creates a new blank definition and links it to the instance.
  #
  # @param model_object [OpenStudio::WorkspaceObject] a SpaceLoadInstance
  def self.ensureSpaceLoadDefinition(model_object)
    return if model_object.nil?

    type_key = model_object.iddObject.name.upcase
    mapping  = SPACE_LOAD_DEFINITION_MAP[type_key]

    unless mapping
      Plugin.log(OpenStudio::Warn,
        "ensureSpaceLoadDefinition: unknown SpaceLoadInstance type '#{type_key}' – skipping")
      return
    end

    definition_type_str = mapping[:definition_type]
    field_index         = mapping[:field_index]

    # If a definition is already linked, nothing to do
    current_def = model_object.getTarget(field_index)
    return unless current_def.empty?

    model        = model_object.model
    idd_type     = OpenStudio::IddObjectType.new(definition_type_str)
    existing     = model.getObjectsByType(idd_type)

    definition_handle = nil

    if !existing.empty?
      # Ask the user whether to reuse an existing definition or create a new one.
      # The C++ code showed a full selector dialog; here we offer a simple YES/NO.
      friendly_type = model_object.iddObject.name.sub(/^OS:/, '').gsub(/(?<=[a-z])(?=[A-Z])/, ' ')
      answer = UI.messagebox(
        "The model has #{existing.size} existing #{friendly_type} Definition(s).\n\n" \
        "Click YES to reuse the first existing definition.\n" \
        "Click NO to create a new blank definition.",
        MB_YESNO
      )

      if answer == 6  # YES – reuse the first existing definition
        definition_handle = existing.first.handle.to_s
      end
      # NO falls through to create a new definition below
    end

    if definition_handle.nil?
      # Create a new blank definition object
      new_def_opt = model.addObject(OpenStudio::IdfObject.new(idd_type))
      unless new_def_opt.empty?
        definition_handle = new_def_opt.get.handle.to_s
      end
    end

    if definition_handle
      model_object.setString(field_index, definition_handle)
    else
      Plugin.log(OpenStudio::Error,
        "ensureSpaceLoadDefinition: failed to create or find a definition for #{type_key}")
    end

  rescue => e
    Plugin.log(OpenStudio::Error, "ensureSpaceLoadDefinition error: #{e.message}")
  end

end # module OpenStudio
