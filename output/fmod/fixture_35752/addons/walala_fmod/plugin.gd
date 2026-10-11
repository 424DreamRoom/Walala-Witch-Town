@tool
extends EditorPlugin
## Native upstream exporter includes raw audio bytes alongside Godot imports.
var exporter: FmodEditorExportPlugin

func _enter_tree() -> void:
	exporter = FmodEditorExportPlugin.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
