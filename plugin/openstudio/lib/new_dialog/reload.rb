# reload.rb
#
# Development reload script for the OpenStudio Inspector Dialog.
# Run this from the SketchUp Ruby Console to reload all Ruby source
# files without restarting SketchUp.
#
# Usage (in SketchUp Ruby Console):
#   load 'C:/repos/openstudio-sketchup-plugin/plugin/openstudio/lib/new_dialog/reload.rb'
#
# The script will:
#   1. Close the existing dialog if open.
#   2. Reload all Ruby source files.
#   3. Re-open the inspector dialog.

puts "--- Reloading OpenStudio Inspector Dialog ---"

# Root directory of the new_dialog implementation
NEW_DIALOG_DIR = File.expand_path(File.dirname(__FILE__)) unless defined?(NEW_DIALOG_DIR)

# Close the dialog if it is currently open so the new code takes effect cleanly
begin
  if defined?(OpenStudio::Inspector::InspectorDialog) &&
     OpenStudio::Inspector::InspectorDialog.instance_variable_get(:@dialog)
    dlg = OpenStudio::Inspector::InspectorDialog.instance_variable_get(:@dialog)
    dlg.close rescue nil
    OpenStudio::Inspector::InspectorDialog.instance_variable_set(:@dialog, nil)
    puts "  Closed existing dialog."
  end
rescue => e
  puts "  (Could not close existing dialog: #{e.message})"
end

# List of files to reload in dependency order
FILES_TO_RELOAD = [
  File.join(NEW_DIALOG_DIR, 'inspector_dialog.rb'),
].freeze

FILES_TO_RELOAD.each do |f|
  if File.exist?(f)
    load f
    puts "  Reloaded: #{File.basename(f)}"
  else
    puts "  WARNING: File not found: #{f}"
  end
end

# Re-open the dialog
begin
  OpenStudio::Inspector::InspectorDialog.show_dialog
  puts "  Dialog opened."
rescue => e
  puts "  ERROR opening dialog: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "--- Done ---"
nil  # suppress printed return value in console
