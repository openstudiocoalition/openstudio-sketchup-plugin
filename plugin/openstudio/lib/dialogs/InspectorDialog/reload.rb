# reload.rb
#
# Development reload script for the OpenStudio Inspector Dialog.
# Run this from the SketchUp Ruby Console to reload all Ruby source
# files without restarting SketchUp.
#
# Usage (in SketchUp Ruby Console):
#   load 'C:/repos/openstudio-sketchup-plugin/plugin/openstudio/lib/dialogs/InspectorDialog/reload.rb'
#
# The script will:
#   1. Close the existing dialog if open.
#   2. Reload all Ruby source files.
#   3. Re-open the inspector dialog.

puts "--- Reloading OpenStudio Inspector Dialog ---"

# Root directory of the inspector dialog implementation
NEW_DIALOG_DIR = File.expand_path(File.dirname(__FILE__)) unless defined?(NEW_DIALOG_DIR)

# Close the dialog if it is currently open so the new code takes effect cleanly.
# InspectorDialog is now an instance class managed by DialogManager.
begin
  inspector = Plugin.dialog_manager&.inspector_dialog
  if inspector&.is_visible
    inspector.hide
    puts "  Closed existing dialog."
  end
rescue => e
  puts "  (Could not close existing dialog: #{e.message})"
end

# List of files to reload in dependency order
FILES_TO_RELOAD = [
  File.join(NEW_DIALOG_DIR, 'inspector_dialog.rb'),
].freeze unless defined?(FILES_TO_RELOAD)

FILES_TO_RELOAD.each do |f|
  if File.exist?(f)
    load f
    puts "  Reloaded: #{File.basename(f)}"
  else
    puts "  WARNING: File not found: #{f}"
  end
end

# Re-open the dialog via the DialogManager instance
begin
  inspector = Plugin.dialog_manager&.inspector_dialog
  if inspector
    inspector.restore_state
    inspector.show
    puts "  Dialog opened."
  else
    puts "  WARNING: No inspector_dialog on dialog_manager. Is the plugin fully loaded?"
  end
rescue => e
  puts "  ERROR opening dialog: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "--- Done ---"
nil  # suppress printed return value in console
