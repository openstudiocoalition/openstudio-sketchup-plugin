# Copilot Instructions for openstudio-sketchup-plugin

## Overview
This project ports Qt-based C++ dialogs and widgets for OpenStudio model editing to a new SketchUp WebDialog implementation. The goal is to generate Ruby and HTML code using the SketchUp WebDialog API, reusing C++ logic where possible, and leveraging the OpenStudio Ruby API for backend operations.

## OpenStudio Model Object Inspector
The OpenStudio Model Object Inspector is a key component that allows users to view and edit properties of OpenStudio model objects. The inspector is designed to be flexible and extensible, allowing for easy addition of new object types and fields as needed.

The select type portion of the inspector provides a list of object types which may be selected.  All Object types are defined in the OpenStudio IDD. The list of object types which may be selected is specified in the `SketchUpPluginPolicy.xml` file.

The select object portion of the inspector allows users to select a specific object from the list of all objects of that type.  The inspector allows adding new objects of the selected type.  The inspector also supports deleting or duplicating the selected object of the selected type. The `SketchUpPluginPolicy.xml` file defines allowable operations for each object type.

When a specific object is selected, the edit object portion of the inspector displays all of the fields for that object, allowing the user to edit the values of those fields.  Fields for each object type are also defined in the OpenStudio IDD.  The `SketchUpPluginPolicy.xml` file defines field access policies for the SketchUp plugin dialogs. The inspector also supports extensible groups, which are groups of fields that can be repeated multiple times (e.g., vertices of a polygon).  The inspector allows users to add or remove instances of extensible groups, and to edit the fields within those groups.  The inspector also supports validation of field values, ensuring that users enter valid data for each field. 

## OpenStudio SDK
The OpenStudio SDK provides C++ and Ruby APIs for energy modeling and simulation. The `utilities` directory under the `openstudio` directory includes the `idd` and `idf` directories.  These classes are the primary classes that the dialogs and widgets interact with to manipulate OpenStudio model objects. A brief overview of the key classes and their responsibilities is provided below. The Ruby API classes mirror the C++ API, so the logic in the C++ dialogs and widgets can be ported to Ruby without specific reference to the OpenStudio Ruby API documentation.

`IddField`: Represents a single schema field (alpha or numeric) in an IDD object, including its properties and validation.
`IddFieldProperties`: Describes detailed properties and metadata for an IDD field, such as type, units, and constraints.
`IddFile`: Parses and manages Input Data Definition (IDD) files, providing access to schema objects and their fields.
`IddObject`: Represents an object schema in the IDD, containing multiple fields and object-level properties.
`IddObjectProperties`: Holds metadata and constraints for an IDD object, including uniqueness, requirement, and memo.
`IddObjectType`: Enumerates and identifies the type of IDD object (e.g., Building, Space, etc.).
`IdfExtensibleGroup`: Wraps a set of extensible fields in an IDF object, allowing dynamic field groups (e.g., vertices).
`IdfFile`: Parses and manages EnergyPlus Input Data Files (IDF), containing ordered lists of IDF objects.
`IdfObject`: Represents a data object in an IDF file, with fields, extensible groups, and validation.
`Workspace`: Manages a collection of WorkspaceObjects, providing context, validation, and file operations for IDF data.
`WorkspaceExtensibleGroup`: Wraps extensible fields in a WorkspaceObject, supporting dynamic relationships and targets.
`WorkspaceObject`: Holds and manipulates data objects in IDF format within a Workspace, maintaining object relationships and validity.

## C++ Code to port
The C++ code in the `existing_cpp_to_port/` directory contains the C++ Qt dialogs and widget logic to port to Ruby and HTML. A brief overview of the key classes and their responsibilities is provided below. These classes will serve as the basis for the new Ruby and HTML implementations.

`AccessPolicyStore`: Manages field access policies and overrides for model objects, controlling which fields are editable, locked, or hidden in the UI.
`IGLineEdit`: Provides a single-line text input widget with validation, min/max/default handling, and event signaling for value changes.
`IGSpinBoxes`: Implements integer and double spin box widgets for numeric input, including locking and event handling.
`InspectorDialog`: Main dialog class orchestrating model object selection, UI updates, and integration with InspectorGadget and other widgets.
`InspectorGadget`: Dynamically interrogates model/workspace objects, generates UI components for their fields, and applies access policies.
`SketchUpPluginPolicy`: Defines XML-based field access rules for SketchUp plugin dialogs, specifying overrides for IDD object fields (e.g., hidden or locked).

## SketchUp WebDialog Example to follow
The code under `sketchup_example_to_follow` contains an example of a SketchUp WebDialog implementation that can be used as a reference for the new Ruby and HTML code. This example demonstrates how to create a WebDialog, load an HTML file, and communicate between Ruby and JavaScript. The key files and their responsibilities are provided below.
`step07.rb`: Creates and configures a SketchUp UI::HtmlDialog, loads the HTML UI, and wires Ruby ↔ JavaScript communication. Handles dialog events, receives data from the HTML UI, and updates SketchUp model objects. Demonstrates event callback patterns and backend integration.
`html/step07.html`: Provides the dialog UI layout using HTML, Vue.js, and Modus/Bootstrap for styling. Implements interactive form fields, event handling, and data binding. Communicates with Ruby backend via SketchUp WebDialog API. Serves as a template for dynamic dialogs.
`vendor/vue.js`: Vue.js JavaScript framework for reactive UI and data binding. Enables dynamic updates and event-driven UI logic in dialogs. Used for form field reactivity and component management.

## Architecture 
1. The backend logic which queries the OpenStudio model for model objects is implemented in Ruby and leverages the OpenStudio Ruby API. See step07.rb for reference.
2. The UI is implemented in HTML and JavaScript. The UI is responsible for displaying the model objects and their fields, and for sending data to the backend for validation and storage. See html/step07.html for reference.
3. The Ruby backend calculates possible values for fields with drop downs by inspecting the IDD file and the OpenStudio model. The backend also sends limits for numeric fields to the UI. The backend only sends valid data to the UI. 
4. The Ruby backend validates the values entered by the user in the UI and updates the OpenStudio model using the Ruby API.

## Porting Workflow
1. Identify Qt dialog/widget logic in `cpp/` (e.g., `InspectorDialog`, `IGLineEdit`).
2. Port backend logic to Ruby using the OpenStudio Ruby API.
3. Implement UI in HTML (`html/step07.html`), referencing vendor assets for styling and interactivity.
4. Use SketchUp WebDialog API for Ruby ↔ HTML communication (see `step07.rb` for patterns).
5. Structure new code for easy integration with Ruby and HTML components.


## Project Conventions & Patterns
- **File Naming:** Dialogs and widgets are named consistently (e.g., `InspectorDialog`, `IGLineEdit`).
- **Integration:** Ruby scripts load HTML dialogs and vendor assets. 
- **Vendor Assets:** External JS/CSS are in `vendor/`, referenced in HTML dialogs.
- **Communication:** Ruby ↔ HTML via SketchUp WebDialog API; backend logic ported from C++ to Ruby.

## Integration Points
- **SketchUp API:** Ruby scripts interact with SketchUp and load dialogs.
- **OpenStudio Ruby API:** Used for model object manipulation in new Ruby code.
- **Web Dialogs:** HTML files loaded as SketchUp dialogs, using vendor assets for UI.


---

**Review and update this file as the project evolves. If any section is unclear or missing, please provide feedback for improvement.**
